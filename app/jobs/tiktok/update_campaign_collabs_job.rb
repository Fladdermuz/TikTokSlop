# When an active campaign's commission rate or message template changes,
# propagate the new terms to every live target collaboration on TikTok so
# creators see the updated offer.
#
# Scope: seller.affiliate_collaboration.write (Update Target Collaboration)
class Tiktok::UpdateCampaignCollabsJob < ApplicationJob
  queue_as :tiktok
  discard_on ActiveRecord::RecordNotFound
  retry_on Tiktok::RateLimitError, wait: :polynomially_longer, attempts: 3

  def perform(campaign_id)
    campaign = Campaign.cross_tenant.find(campaign_id)
    return unless campaign.active?
    shop = campaign.shop
    token = TiktokToken.cross_tenant.find_by(shop: shop)
    return unless token

    collab = Tiktok::Resources::AffiliateCollaboration.new(token: token, shop_cipher: token.shop_cipher)

    campaign.invites.where(status: %w[sent accepted]).where.not(external_id: nil).find_each do |invite|
      attrs = {}
      attrs[:commission_rate] = campaign.commission_rate if campaign.commission_rate.present?
      attrs[:message]         = invite.message if invite.message.present?
      next if attrs.empty?

      begin
        collab.update(collaboration_id: invite.external_id, **attrs)
      rescue Tiktok::Error => e
        Rails.logger.warn("[update_campaign_collabs] invite=#{invite.id}: #{e.message}")
      end
    end
  end
end
