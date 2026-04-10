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
      # Most sellers have one shop; we use the first.
      def list
        @client.get("/api/seller/202309/shops")
      end

      def first_shop
        body = list
        Array(body.dig("data", "shops")).first
      end
    end
  end
end
