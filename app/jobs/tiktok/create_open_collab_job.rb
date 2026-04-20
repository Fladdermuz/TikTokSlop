# Create an Open Collaboration on TikTok for an open-mode campaign.
# Runs asynchronously when a draft campaign is activated.
#
# Scope: seller.affiliate_collaboration.write (Create Open Collaboration)
class Tiktok::CreateOpenCollabJob < ApplicationJob
  queue_as :tiktok
  discard_on ActiveRecord::RecordNotFound
  retry_on Tiktok::RateLimitError, wait: :polynomially_longer, attempts: 3

  def perform(campaign_id)
    campaign = Campaign.cross_tenant.find(campaign_id)
    return unless campaign.open_mode?
    return unless campaign.active?
    return if campaign.external_id.present?

    shop = campaign.shop
    token = TiktokToken.cross_tenant.find_by(shop: shop)
    return unless token

    collab = Tiktok::Resources::AffiliateCollaboration.new(token: token, shop_cipher: token.shop_cipher)

    external_id = collab.create_open(
      product_ids:     [campaign.product.external_id].compact,
      commission_rate: campaign.commission_rate,
      description:     campaign.notes.to_s
    )

    campaign.update_columns(external_id: external_id, updated_at: Time.current) if external_id.present?
  rescue Tiktok::Error => e
    Rails.logger.error("[create_open_collab] campaign=#{campaign_id}: #{e.message}")
    raise
  end
end
