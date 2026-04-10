module Tiktok
  # 401 / 403, or business code indicating bad/expired token.
  # Catch this in jobs to trigger Tiktok::RefreshTokenJob and retry.
  class AuthError < Error; end
end
