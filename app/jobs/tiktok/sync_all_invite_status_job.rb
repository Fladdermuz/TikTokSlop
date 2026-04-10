# Recurring fan-out: enqueues SyncInviteStatusJob per shop that has sent invites.
class Tiktok::SyncAllInviteStatusJob < ApplicationJob
  queue_as :tiktok

  def perform
    shop_ids = Invite.cross_tenant.where(status: "sent").distinct.pluck(:shop_id)
    shop_ids.each do |shop_id|
      Tiktok::SyncInviteStatusJob.perform_later(shop_id)
    end
    Rails.logger.info("[sync all invites] enqueued #{shop_ids.size} per-shop sync jobs")
  end
end
