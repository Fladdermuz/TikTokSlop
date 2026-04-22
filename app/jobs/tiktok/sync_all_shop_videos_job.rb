# Recurring fan-out: enqueues SyncShopVideosJob per connected shop.
class Tiktok::SyncAllShopVideosJob < ApplicationJob
  queue_as :tiktok

  def perform
    shop_ids = TiktokToken.cross_tenant.distinct.pluck(:shop_id)
    shop_ids.each do |shop_id|
      Tiktok::SyncShopVideosJob.perform_later(shop_id)
    end
    Rails.logger.info("[sync all videos] enqueued #{shop_ids.size} per-shop sync jobs")
  end
end
