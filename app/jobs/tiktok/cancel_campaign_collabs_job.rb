# When a campaign transitions to paused or ended, cancel the corresponding
# target collaborations on TikTok so creators don't keep seeing a stale offer.
#
# Only cancels invites in "sent" state — already-accepted collaborations are
# commitments we don't retract on pause/end (creator has already agreed).
# Failed/expired/declined invites have no live TikTok collab to cancel.
#
# Scope: seller.affiliate_collaboration.write (Remove Target Collaboration)
class Tiktok::CancelCampaignCollabsJob < ApplicationJob
  queue_as :tiktok
  discard_on ActiveRecord::RecordNotFound
  retry_on Tiktok::RateLimitError, wait: :polynomially_longer, attempts: 3

  def perform(campaign_id)
    campaign = Campaign.cross_tenant.find(campaign_id)
    shop = campaign.shop
    token = TiktokToken.cross_tenant.find_by(shop: shop)
    return unless token

    collab = Tiktok::Resources::AffiliateCollaboration.new(token: token, shop_cipher: token.shop_cipher)

    campaign.invites.where(status: "sent").where.not(external_id: nil).find_each do |invite|
      begin
        collab.cancel(invite.external_id)
        invite.update!(
          status: "expired",
          raw: invite.raw.merge("cancelled_due_to_campaign_transition" => campaign.status, "cancelled_at" => Time.current.iso8601)
        )
      rescue Tiktok::Error => e
        Rails.logger.warn("[cancel_campaign_collabs] invite=#{invite.id} collab=#{invite.external_id} failed: #{e.message}")
      end
    end
  end
end
