# Refresh a single TiktokToken if it's nearing expiry.
#
# Idempotent and safe to enqueue redundantly. Uses cross_tenant access because
# jobs run with no Current.shop set.
class Tiktok::RefreshTokenJob < ApplicationJob
  queue_as :tiktok

  REFRESH_BUFFER = 30.minutes

  def perform(tiktok_token_id)
    token = TiktokToken.cross_tenant.find_by(id: tiktok_token_id)
    return if token.nil?
    return unless token.access_expired?(buffer: REFRESH_BUFFER)

    if token.refresh_expired?
      Rails.logger.warn("[tiktok refresh] refresh token expired for shop=#{token.shop_id}; user must re-authorize")
      return
    end

    pair = Tiktok::Resources::Authorization.refresh(token.refresh_token)

    token.update!(
      access_token:       pair.access_token,
      refresh_token:      pair.refresh_token,
      access_expires_at:  pair.access_expires_at,
      refresh_expires_at: pair.refresh_expires_at
    )
    Rails.logger.info("[tiktok refresh] refreshed shop=#{token.shop_id} new_expiry=#{token.access_expires_at}")
  rescue Tiktok::AuthError => e
    # Refresh token rejected — typically because the user disconnected on TikTok's
    # side, or scopes changed. The shop admin must re-authorize.
    Rails.logger.error("[tiktok refresh] AuthError shop=#{token&.shop_id} message=#{e.message}")
  end
end
