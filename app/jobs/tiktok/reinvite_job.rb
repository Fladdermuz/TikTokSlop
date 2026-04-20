# Reinvite a creator at a different commission rate. Cancels the current
# Target Collaboration on TikTok, then creates a new one with the specified
# commission rate using the same creator + campaign message context.
#
# Scopes exercised:
#   - Remove Target Collaboration (seller.affiliate_collaboration.write)
#   - Create Target Collaboration (seller.affiliate_collaboration.write)
class Tiktok::ReinviteJob < ApplicationJob
  queue_as :tiktok
  discard_on ActiveRecord::RecordNotFound
  retry_on Tiktok::RateLimitError, wait: :polynomially_longer, attempts: 5

  def perform(invite_id, new_commission_rate)
    invite = Invite.cross_tenant.find(invite_id)
    shop = invite.shop
    token = TiktokToken.cross_tenant.find_by(shop: shop)
    return unless token

    collab = Tiktok::Resources::AffiliateCollaboration.new(token: token, shop_cipher: token.shop_cipher)

    if invite.external_id.present?
      begin
        collab.cancel(invite.external_id)
      rescue Tiktok::Error => e
        Rails.logger.warn("[reinvite] could not cancel old collab=#{invite.external_id}: #{e.message}")
      end
    end

    new_external_id = collab.create_targeted(
      creator_id:      invite.creator.external_id,
      product_id:      invite.campaign.product.external_id,
      commission_rate: new_commission_rate,
      message:         invite.message.to_s,
      sample_offer:    invite.campaign.sample_offer?
    )

    invite.update!(
      status: "sent",
      external_id: new_external_id,
      sent_at: Time.current,
      responded_at: nil,
      error_message: nil,
      retry_count: invite.retry_count + 1,
      raw: invite.raw.merge("reinvited_at" => Time.current.iso8601, "reinvite_commission_rate" => new_commission_rate)
    )
  end
end
