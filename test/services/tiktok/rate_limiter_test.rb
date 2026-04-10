require "test_helper"

class Tiktok::RateLimiterTest < ActiveSupport::TestCase
  setup do
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @original_cache
  end

  test "allow? returns true while under limit" do
    limiter = Tiktok::RateLimiter.new(shop_id: 1, bucket: :invites, limit: 3, window: 60)
    3.times do
      assert limiter.allow?
      limiter.record!
    end
  end

  test "allow? returns false at limit" do
    limiter = Tiktok::RateLimiter.new(shop_id: 1, bucket: :invites, limit: 2, window: 60)
    limiter.record!
    limiter.record!
    refute limiter.allow?
  end

  test "buckets are independent per shop" do
    a = Tiktok::RateLimiter.new(shop_id: 1, bucket: :invites, limit: 1, window: 60)
    b = Tiktok::RateLimiter.new(shop_id: 2, bucket: :invites, limit: 1, window: 60)
    a.record!
    refute a.allow?
    assert b.allow?, "shop 2's bucket is unaffected by shop 1"
  end

  test "buckets are independent per bucket name" do
    invites = Tiktok::RateLimiter.new(shop_id: 1, bucket: :invites, limit: 1, window: 60)
    search  = Tiktok::RateLimiter.new(shop_id: 1, bucket: :search,  limit: 1, window: 60)
    invites.record!
    refute invites.allow?
    assert search.allow?, "search bucket is independent of invites bucket"
  end

  test "reset! clears the counter" do
    limiter = Tiktok::RateLimiter.new(shop_id: 1, bucket: :invites, limit: 1, window: 60)
    limiter.record!
    refute limiter.allow?
    limiter.reset!
    assert limiter.allow?
  end
end
