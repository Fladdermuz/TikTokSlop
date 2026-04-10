require "openssl"

# Pure-function signing helper for TikTok Shop API requests.
# Verified against EcomPHP/tiktokshop-php and tudinhacoustic/tiktok-shop reference
# implementations. See docs/TIKTOK_API_NOTES.md for the algorithm specification.
module Tiktok
  class Signer
    EXCLUDED_PARAMS = %w[sign access_token x-tts-access-token app_secret token].freeze

    class << self
      # Compute the HMAC-SHA256 sign value for a TikTok Shop API request.
      #
      # @param method [Symbol] :get, :post, etc.
      # @param path   [String] URI path only, e.g. "/api/orders/202309/list"
      # @param query  [Hash]   query parameters (will be filtered + sorted)
      # @param body   [String, nil] raw request body bytes for non-GET, non-multipart
      # @param app_secret [String]
      # @param multipart  [Boolean] true if Content-Type is multipart/form-data
      # @return [String] lowercase hex digest
      def sign(method:, path:, query:, app_secret:, body: nil, multipart: false)
        canonical = canonical_string(query)
        to_sign = path + canonical

        if include_body?(method, body, multipart)
          to_sign += body.to_s
        end

        wrapped = "#{app_secret}#{to_sign}#{app_secret}"
        OpenSSL::HMAC.hexdigest("sha256", app_secret, wrapped)
      end

      # The portion of the canonical string built from query parameters:
      # filter out excluded keys, sort by ASCII byte order, concat as `key+value`.
      def canonical_string(query)
        filtered = (query || {}).reject { |k, _| EXCLUDED_PARAMS.include?(k.to_s) }
        filtered
          .sort_by { |k, _| k.to_s }
          .map { |k, v| "#{k}#{v}" }
          .join
      end

      private

      def include_body?(method, body, multipart)
        return false if multipart
        return false if method.to_s.downcase == "get"
        return false if body.nil? || body.empty?
        true
      end
    end
  end
end
