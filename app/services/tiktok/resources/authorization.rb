# OAuth token exchange and refresh.
#
# These endpoints live on the auth host, NOT the API host, and they take
# `app_secret` as a query parameter (the only place we send it on the wire).
# They do NOT require the standard `sign` parameter.
module Tiktok
  module Resources
    class Authorization
      # Exchange an `auth_code` (from the OAuth callback) for a token pair.
      # @return [Tiktok::Types::TokenPair]
      def self.exchange_code(auth_code)
        client = build_auth_client
        body = client.get("/api/v2/token/get",
          app_key:    Tiktok::Client.app_key,
          app_secret: Tiktok::Client.app_secret,
          auth_code:  auth_code,
          grant_type: "authorized_code"
        )
        Tiktok::Types::TokenPair.from_api(body)
      end

      # Refresh an existing token using its refresh_token.
      # @return [Tiktok::Types::TokenPair]
      def self.refresh(refresh_token)
        client = build_auth_client
        body = client.get("/api/v2/token/refresh",
          app_key:       Tiktok::Client.app_key,
          app_secret:    Tiktok::Client.app_secret,
          refresh_token: refresh_token,
          grant_type:    "refresh_token"
        )
        Tiktok::Types::TokenPair.from_api(body)
      end

      # Build the URL the user is redirected to in order to authorize the app.
      # @param state [String] signed state token (CSRF + shop binding)
      def self.authorize_url(state:)
        URI::HTTPS.build(
          host: URI(Tiktok::Client.auth_base_url).host,
          path: "/oauth/authorize",
          query: URI.encode_www_form(
            app_key:      Tiktok::Client.app_key,
            state:        state,
            redirect_uri: Rails.application.credentials.dig(:tiktok, :redirect_uri)
          )
        ).to_s
      end

      # Build a state token containing the shop_id + nonce, signed so we can
      # verify it on callback. Returns a string.
      def self.build_state(shop_id:, user_id:)
        Rails.application.message_verifier(:tiktok_oauth_state).generate(
          { shop_id: shop_id, user_id: user_id, nonce: SecureRandom.hex(8), iat: Time.current.to_i },
          expires_in: 15.minutes
        )
      end

      # Verify and decode a state token. Raises ActiveSupport::MessageVerifier::InvalidSignature
      # if tampered or expired.
      def self.verify_state(token)
        Rails.application.message_verifier(:tiktok_oauth_state).verify(token)
      end

      def self.build_auth_client
        Tiktok::Client.new(token: nil, base_url: Tiktok::Client.auth_base_url)
      end
    end
  end
end
