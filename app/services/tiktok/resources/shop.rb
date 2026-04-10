# Shop info — used after OAuth to capture shop_cipher and shop name.
module Tiktok
  module Resources
    class Shop
      def initialize(token:)
        @token = token
        @client = Tiktok::Client.new(token: token)
      end

      # GET /api/seller/202309/shops
      # Returns the list of shops authorized for the given access token.
      def list
        @client.get("/api/seller/202309/shops")
      end

      # Most sellers have one shop; this is the convenience accessor used after
      # OAuth to capture shop_cipher / shop name.
      def first
        body = list
        Array(body.dig("data", "shops")).first
      end

      # Class-level convenience for callers (and easier to stub in tests).
      def self.first_for(token:)
        new(token: token).first
      end
    end
  end
end
