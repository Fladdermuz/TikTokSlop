require "test_helper"

class Tiktok::RefreshTokenJobTest < ActiveJob::TestCase
  setup do
    @shop = shops(:alpha)
    @token = TiktokToken.create!(
      shop: @shop,
      external_shop_id: "tt_alpha",
      access_token: "old_access",
      refresh_token: "old_refresh",
      access_expires_at: 5.minutes.from_now,    # within buffer
      refresh_expires_at: 30.days.from_now
    )
  end

  teardown do
    Current.reset
  end

  test "refreshes when access expiry is within buffer" do
    new_pair = Tiktok::Types::TokenPair.new(
      access_token: "new_access",
      refresh_token: "new_refresh",
      access_expires_at: 7.days.from_now,
      refresh_expires_at: 365.days.from_now,
      seller_name: nil, open_id: nil, raw: {}
    )

    stub_method(Tiktok::Resources::Authorization, :refresh, ->(rt) { assert_equal "old_refresh", rt; new_pair }) do
      Tiktok::RefreshTokenJob.new.perform(@token.id)
    end

    @token.reload
    assert_equal "new_access", @token.access_token
    assert_equal "new_refresh", @token.refresh_token
    assert @token.access_expires_at > 6.days.from_now
  end

  test "no-op when access expiry is far in the future" do
    @token.update!(access_expires_at: 7.days.from_now)
    refresh_called = false
    stub_method(Tiktok::Resources::Authorization, :refresh, ->(_) { refresh_called = true; nil }) do
      Tiktok::RefreshTokenJob.new.perform(@token.id)
    end
    refute refresh_called, "should not call refresh when access expiry is well outside buffer"
  end

  test "no-op when refresh token itself has expired" do
    @token.update!(refresh_expires_at: 1.minute.ago)
    refresh_called = false
    stub_method(Tiktok::Resources::Authorization, :refresh, ->(_) { refresh_called = true; nil }) do
      Tiktok::RefreshTokenJob.new.perform(@token.id)
    end
    refute refresh_called, "must not attempt refresh with expired refresh_token"
  end

  test "swallows AuthError so the job doesn't infinite-retry" do
    stub_method(Tiktok::Resources::Authorization, :refresh, ->(_) { raise Tiktok::AuthError.new("token revoked", code: 36004004) }) do
      assert_nothing_raised { Tiktok::RefreshTokenJob.new.perform(@token.id) }
    end
  end

  test "no-op when token is missing" do
    assert_nothing_raised { Tiktok::RefreshTokenJob.new.perform(999_999) }
  end
end
