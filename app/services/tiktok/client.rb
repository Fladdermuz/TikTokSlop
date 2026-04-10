require "faraday"
require "faraday/retry"

# Per-request HTTP client for the TikTok Shop API.
#
# Construct one client per call site, optionally bound to a TiktokToken (the
# normal case for shop-scoped endpoints) or with no token at all (for the auth
# host's token exchange endpoints).
#
# Examples:
#
#   client = Tiktok::Client.new(token: shop.tiktok_token)
#   resp = client.get("/api/affiliate_creator/202405/creators/search", { shop_cipher: shop.cipher })
#
#   auth_client = Tiktok::Client.new(token: nil, base_url: Tiktok::Client.auth_base_url)
#   resp = auth_client.get("/api/v2/token/get", { auth_code: code, app_secret: secret, ... })
#
# All HTTP errors are normalized to Tiktok::* exceptions by the middleware stack.
module Tiktok
  class Client
    DEFAULT_TIMEOUT = 15
    DEFAULT_OPEN_TIMEOUT = 5

    class << self
      def app_key
        Rails.application.credentials.dig(:tiktok, :app_key)
      end

      def app_secret
        Rails.application.credentials.dig(:tiktok, :app_secret)
      end

      def api_base_url
        if Rails.application.credentials.dig(:tiktok, :use_sandbox)
          Rails.application.credentials.dig(:tiktok, :sandbox_base_url)
        else
          Rails.application.credentials.dig(:tiktok, :api_base_url)
        end
      end

      def auth_base_url
        Rails.application.credentials.dig(:tiktok, :auth_base_url)
      end
    end

    attr_reader :token, :base_url

    def initialize(token: nil, base_url: nil, app_key: nil, app_secret: nil)
      @token = token
      @base_url = base_url || self.class.api_base_url
      @app_key = app_key || self.class.app_key
      @app_secret = app_secret || self.class.app_secret
    end

    def get(path, params = {})
      response = connection.get(path, params)
      response.body
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
      raise Tiktok::TransportError.new(e.message)
    end

    def post(path, body = {}, params = {})
      response = connection.post(path) do |req|
        req.params = params
        req.body = body unless body.nil?
      end
      response.body
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
      raise Tiktok::TransportError.new(e.message)
    end

    def delete(path, params = {})
      response = connection.delete(path, params)
      response.body
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
      raise Tiktok::TransportError.new(e.message)
    end

    private

    def connection
      @connection ||= Faraday.new(url: @base_url) do |f|
        f.options.timeout      = DEFAULT_TIMEOUT
        f.options.open_timeout = DEFAULT_OPEN_TIMEOUT

        f.request :json  # serialize request bodies as JSON
        f.request :retry, max: 3, interval: 0.5, backoff_factor: 2, interval_randomness: 0.5,
                  retry_statuses: [ 502, 503, 504 ],
                  exceptions: [ Faraday::TimeoutError, Faraday::ConnectionFailed, Errno::ECONNRESET ]

        # Sign AFTER body serialization so we hash the exact bytes that get sent.
        f.use Tiktok::Middleware::RequestSigner,
              app_key: @app_key,
              app_secret: @app_secret,
              access_token: @token&.access_token

        f.response :json, content_type: /\bjson$/
        f.use Tiktok::Middleware::ErrorHandler

        f.adapter Faraday.default_adapter
      end
    end
  end
end
