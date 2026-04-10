# Creates and publishes a TAP (TikTok Affiliate Partner) campaign on TikTok
# when a local Campaign is activated. Stores the returned external campaign ID
# on the Campaign record.
#
# Enqueued by Campaign#transition_to! when transitioning to "active".
# The status transition is NOT blocked on this job — it runs async.
#
# Requires: partner.tap_campaign.write scope.
class Tiktok::CreateTapCampaignJob < ApplicationJob
  queue_as :tiktok
  retry_on Tiktok::RateLimitError, wait: :polynomially_longer, attempts: 5
  discard_on ActiveRecord::RecordNotFound

  def perform(campaign_id)
    campaign = Campaign.cross_tenant.find(campaign_id)

    # Only proceed if still active and not already synced to TikTok
    return if campaign.external_id.present?
    return unless campaign.active?

    shop = campaign.shop
    token = TiktokToken.cross_tenant.find_by(shop: shop)

    unless token
      Rails.logger.info("[tap_campaign] no TikTok connection for shop=#{shop.id}, skipping")
      return
    end

    tap = Tiktok::Resources::TapCampaign.new(token: token, shop_cipher: token.shop_cipher)

    # Build campaign attributes from local record. product_external_id holds
    # the TikTok product SKU set during product sync.
    attrs = build_campaign_attrs(campaign)

    # Step 1: create a draft campaign on TikTok
    external_campaign_id = tap.create(**attrs)

    unless external_campaign_id.present?
      Rails.logger.error("[tap_campaign] TikTok returned no campaign_id for campaign=#{campaign.id}")
      return
    end

    # Step 2: publish the draft to make it live
    tap.publish(campaign_id: external_campaign_id)

    # Step 3: persist the external ID locally
    campaign.update_columns(external_id: external_campaign_id, updated_at: Time.current)

    Rails.logger.info("[tap_campaign] campaign=#{campaign.id} published as tiktok_campaign_id=#{external_campaign_id}")

  rescue Tiktok::AuthError => e
    Rails.logger.error("[tap_campaign] auth error for campaign=#{campaign_id}: #{e.message}")
    token = TiktokToken.cross_tenant.find_by(shop: Campaign.cross_tenant.find(campaign_id).shop)
    Tiktok::RefreshTokenJob.perform_later(token.id) if token
  rescue Tiktok::RateLimitError
    raise # let retry_on handle it
  rescue Tiktok::ValidationError => e
    Rails.logger.error("[tap_campaign] TikTok rejected campaign=#{campaign_id}: #{e.message} (code=#{e.code})")
  rescue Tiktok::Error => e
    Rails.logger.error("[tap_campaign] #{e.class.name}: #{e.message} campaign=#{campaign_id} request_id=#{e.request_id}")
    raise # allow GoodJob/Solid Queue to retry per default policy
  end

  private

  def build_campaign_attrs(campaign)
    attrs = {
      name:            campaign.name,
      commission_rate: campaign.commission_rate
    }

    # Include product reference if we have a TikTok product ID
    if campaign.product_external_id.present?
      attrs[:product_ids] = [campaign.product_external_id]
    elsif campaign.product&.external_id.present?
      attrs[:product_ids] = [campaign.product.external_id]
    end

    attrs[:with_sample] = campaign.sample_offer? if campaign.sample_offer?
    attrs[:description] = campaign.notes if campaign.notes.present?

    attrs
  end
end
