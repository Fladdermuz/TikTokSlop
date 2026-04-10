# Per-shop, per-bucket sliding-window rate limiter backed by Rails.cache
# (which is Solid Cache in production, MemoryStore in dev/test).
#
# Buckets are independent — one for invites, one for searches, etc. — so you can
# size each TikTok endpoint's quota separately.
#
# Usage:
#   limiter = Tiktok::RateLimiter.new(shop_id: shop.id, bucket: :invites)
#   if limiter.allow?
#     send_invite
#     limiter.record!
#   else
#     reschedule_with_delay(limiter.retry_after)
#   end
#
# Defaults are conservative — adjust per bucket once we measure actual TikTok
# limits in production.
module Tiktok
  class RateLimiter
    DEFAULTS = {
      invites:    { limit: 30, window: 60 },     # 30 invites per minute per shop
      samples:    { limit: 10, window: 60 },     # 10 samples per minute per shop
      search:     { limit: 60, window: 60 },     # 60 searches per minute per shop
      generic:    { limit: 120, window: 60 }     # fallback bucket
    }.freeze

    attr_reader :shop_id, :bucket, :limit, :window

    def initialize(shop_id:, bucket: :generic, limit: nil, window: nil)
      @shop_id = shop_id
      @bucket = bucket
      defaults = DEFAULTS[bucket] || DEFAULTS[:generic]
      @limit = limit || defaults[:limit]
      @window = window || defaults[:window]
    end

    def allow?
      current_count < limit
    end

    def record!
      Rails.cache.increment(cache_key, 1, expires_in: window) || begin
        # increment returns nil if key doesn't exist on some stores; init then re-inc
        Rails.cache.write(cache_key, 1, expires_in: window)
        1
      end
    end

    def current_count
      Rails.cache.read(cache_key).to_i
    end

    # Estimated seconds until the next request would be allowed.
    # Sliding-window approximation: assume calls are spread evenly.
    def retry_after
      remaining_in_window = @window
      [ remaining_in_window, 1 ].max
    end

    def reset!
      Rails.cache.delete(cache_key)
    end

    private

    def cache_key
      "tiktok:ratelimit:shop_#{shop_id}:#{bucket}:#{Time.current.to_i / window}"
    end
  end
end
