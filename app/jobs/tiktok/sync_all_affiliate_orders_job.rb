# Recurring fan-out: enqueues SyncAffiliateOrdersJob per connected shop.
class Tiktok::SyncAllAffiliateOrdersJob < ApplicationJob
  queue_as :tiktok

  def perform
    shop_ids = TiktokToken.cross_tenant.distinct.pluck(:shop_id)
    shop_ids.each do |shop_id|
      Tiktok::SyncAffiliateOrdersJob.perform_later(shop_id)
    end
    Rails.logger.info("[sync all affiliate orders] enqueued #{shop_ids.size} per-shop sync jobs")
  end
end
