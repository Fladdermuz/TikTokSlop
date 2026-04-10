# Polls TikTok for status updates on sent invites. Detects accepted/declined
# transitions. Runs per-shop, enqueued by the recurring SyncAllInviteStatusJob.
class Tiktok::SyncInviteStatusJob < ApplicationJob
  queue_as :tiktok

  def perform(shop_id)
    shop = Shop.find_by(id: shop_id)
    return unless shop

    token = TiktokToken.cross_tenant.find_by(shop: shop)
    return unless token

    pending_invites = Invite.for_shop(shop).where(status: "sent").where.not(external_id: nil)
    return if pending_invites.empty?

    collab = Tiktok::Resources::AffiliateCollaboration.new(token: token, shop_cipher: token.shop_cipher)

    pending_invites.find_each do |invite|
      sync_one(invite, collab)
    rescue Tiktok::Error => e
      Rails.logger.warn("[sync invite] error for invite=#{invite.id}: #{e.class.name}: #{e.message}")
    end
  end

  private

  def sync_one(invite, collab)
    response = collab.find(invite.external_id)
    data = response.is_a?(Hash) ? response["data"] || response : response

    remote_status = data["status"]&.downcase
    return if remote_status.blank?

    new_status = map_status(remote_status)
    return if new_status == invite.status

    invite.update!(
      status: new_status,
      responded_at: Time.current,
      raw: invite.raw.merge("last_sync" => data)
    )
    Rails.logger.info("[sync invite] invite=#{invite.id} #{invite.status_previously_was} → #{new_status}")
  end

  def map_status(remote)
    case remote
    when "accepted", "approved" then "accepted"
    when "declined", "rejected" then "declined"
    when "expired" then "expired"
    else remote
    end
  end
end
