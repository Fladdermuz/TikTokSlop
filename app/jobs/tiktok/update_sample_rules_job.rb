# Push sample rule changes (max samples per creator, validity window, follower
# threshold) to an active Open Collaboration on TikTok when the local campaign
# record's sample-rule fields change.
#
# Scope: seller.affiliate_collaboration.write (Edit Open Collaboration Sample Rule)
class Tiktok::UpdateSampleRulesJob < ApplicationJob
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

    attrs = {}
    attrs[:max_samples_per_creator]       = campaign.max_samples_per_creator       if campaign.max_samples_per_creator.present?
    attrs[:valid_days]                    = campaign.sample_valid_days             if campaign.sample_valid_days.present?
    attrs[:min_follower_threshold]        = campaign.sample_min_follower_threshold if campaign.sample_min_follower_threshold.present?
    attrs[:active]                        = true
    return if attrs.size <= 1

    Tiktok::Resources::AffiliateCollaboration.new(token: token, shop_cipher: token.shop_cipher)
      .edit_sample_rules(collaboration_id: campaign.external_id, **attrs)
  rescue Tiktok::Error => e
    Rails.logger.warn("[update_sample_rules] campaign=#{campaign_id}: #{e.message}")
  end
end
