# Terminate an Open Collaboration on TikTok when an open-mode campaign is
# paused or ended.
#
# Scope: seller.affiliate_collaboration.write (Remove Open Collaboration)
class Tiktok::RemoveOpenCollabJob < ApplicationJob
  queue_as :tiktok
  discard_on ActiveRecord::RecordNotFound
  retry_on Tiktok::RateLimitError, wait: :polynomially_longer, attempts: 3

  def perform(campaign_id)
    campaign = Campaign.cross_tenant.find(campaign_id)
    return unless campaign.open_mode?
    return if campaign.external_id.blank?

    shop = campaign.shop
    token = TiktokToken.cross_tenant.find_by(shop: shop)
    return unless token

    Tiktok::Resources::AffiliateCollaboration.new(token: token, shop_cipher: token.shop_cipher)
      .remove_open(campaign.external_id)

    campaign.update_columns(external_id: nil, updated_at: Time.current)
  rescue Tiktok::Error => e
    Rails.logger.warn("[remove_open_collab] campaign=#{campaign_id}: #{e.message}")
  end
end
