# Recurring fan-out job. Enqueues a Tiktok::RefreshTokenJob for every token
# whose access expiry is within the refresh buffer.
class Tiktok::RefreshAllTokensJob < ApplicationJob
  queue_as :tiktok

  def perform
    threshold = Time.current + Tiktok::RefreshTokenJob::REFRESH_BUFFER
    candidates = TiktokToken.cross_tenant.where("access_expires_at <= ?", threshold)
    count = 0
    candidates.find_each do |token|
      Tiktok::RefreshTokenJob.perform_later(token.id)
      count += 1
    end
    Rails.logger.info("[tiktok refresh] enqueued #{count} token refresh jobs")
  end
end
