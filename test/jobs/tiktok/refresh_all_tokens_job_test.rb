require "test_helper"

class Tiktok::RefreshAllTokensJobTest < ActiveJob::TestCase
  setup do
    @alpha = shops(:alpha)
    @beta  = shops(:beta)

    @near_expiry = TiktokToken.create!(
      shop: @alpha,
      external_shop_id: "near",
      access_token: "a", refresh_token: "r",
      access_expires_at: 5.minutes.from_now,
      refresh_expires_at: 30.days.from_now
    )

    @far_expiry = TiktokToken.create!(
      shop: @beta,
      external_shop_id: "far",
      access_token: "a", refresh_token: "r",
      access_expires_at: 7.days.from_now,
      refresh_expires_at: 30.days.from_now
    )
  end

  teardown do
    Current.reset
  end

  test "enqueues per-token refresh jobs only for tokens within the buffer" do
    assert_enqueued_jobs 1, only: Tiktok::RefreshTokenJob do
      Tiktok::RefreshAllTokensJob.new.perform
    end
    assert_enqueued_with(job: Tiktok::RefreshTokenJob, args: [ @near_expiry.id ])
  end
end
