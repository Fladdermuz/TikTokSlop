# When a paused campaign is resumed, recreate the target collaborations we
# cancelled at pause-time. We identify those invites by the flag we wrote
# into raw during CancelCampaignCollabsJob.
#
# Scope: seller.affiliate_collaboration.write (Create Target Collaboration)
class Tiktok::RecreateCampaignCollabsJob < ApplicationJob
  queue_as :tiktok
  discard_on ActiveRecord::RecordNotFound
  retry_on Tiktok::RateLimitError, wait: :polynomially_longer, attempts: 3

  def perform(campaign_id)
    campaign = Campaign.cross_tenant.find(campaign_id)
    shop = campaign.shop
    token = TiktokToken.cross_tenant.find_by(shop: shop)
    return unless token

    collab = Tiktok::Resources::AffiliateCollaboration.new(token: token, shop_cipher: token.shop_cipher)

    campaign.invites.where(status: "expired").find_each do |invite|
      next unless invite.raw["cancelled_due_to_campaign_transition"].present?

      external_id = collab.create_targeted(
        creator_id:      invite.creator.external_id,
        product_id:      campaign.product.external_id,
        commission_rate: campaign.commission_rate,
        message:         invite.message.to_s,
        sample_offer:    campaign.sample_offer?
      )

      invite.update!(
        status: "sent",
        external_id: external_id,
        sent_at: Time.current,
        raw: invite.raw.except("cancelled_due_to_campaign_transition", "cancelled_at").merge("resumed_at" => Time.current.iso8601)
      )
    rescue Tiktok::Error => e
      Rails.logger.warn("[recreate_campaign_collabs] invite=#{invite.id}: #{e.message}")
    end
  end
end
