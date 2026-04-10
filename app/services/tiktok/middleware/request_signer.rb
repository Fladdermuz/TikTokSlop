# Faraday middleware that signs every outgoing TikTok Shop API request:
# - injects `app_key` and `timestamp` query params if missing
# - sets the `x-tts-access-token` header from the bound TiktokToken (if present)
# - computes and appends the `sign` query param last
#
# This middleware MUST run after request body serialization (i.e. after Faraday's
# `request :json` middleware) so that the body bytes used for signing match what
# actually goes on the wire.
module Tiktok
  module Middleware
    class RequestSigner < Faraday::Middleware
      def initialize(app, app_key:, app_secret:, access_token: nil)
        super(app)
        @app_key = app_key
        @app_secret = app_secret
        @access_token = access_token
      end

      def on_request(env)
        query = parse_query(env.url.query)
        query["app_key"]   ||= @app_key
        query["timestamp"] ||= Time.now.to_i.to_s

        body = env.body.is_a?(String) ? env.body : env.body&.to_s
        multipart = env.request_headers["Content-Type"].to_s.include?("multipart/form-data")

        sign = Tiktok::Signer.sign(
          method: env.method,
          path: env.url.path,
          query: query,
          body: body,
          multipart: multipart,
          app_secret: @app_secret
        )
        query["sign"] = sign

        env.url.query = build_query(query)

        if @access_token.present?
          env.request_headers["x-tts-access-token"] = @access_token
        end
      end

      private

      def parse_query(qs)
        return {} if qs.blank?
        URI.decode_www_form(qs).to_h
      end

      def build_query(hash)
        URI.encode_www_form(hash)
      end
    end
  end
end
