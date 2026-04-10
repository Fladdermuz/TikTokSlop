# Recurring fan-out: finds all samples needing a Spark Code follow-up and
# enqueues per-sample SendSampleFollowUpJob.
class Tiktok::ScanForFollowUpsJob < ApplicationJob
  queue_as :tiktok

  def perform
    samples = Sample.cross_tenant.needs_follow_up
    count = 0
    samples.find_each do |sample|
      Tiktok::SendSampleFollowUpJob.perform_later(sample.id)
      count += 1
    end
    Rails.logger.info("[follow-up scan] enqueued #{count} follow-up jobs")
  end
end
