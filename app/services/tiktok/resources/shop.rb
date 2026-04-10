# Shop info — seller.shop.info scope.
#
# Real endpoints from TikTok Partner Center:
#   - Get Active Shops — retrieves all active shops belonging to a seller
#   - Get Global Seller Warehouse — warehouse info
#   - Get Seller Permissions — cross-border permissions
module Tiktok
  module Resources
    class Shop
      def initialize(token:)
        @token = token
        @client = Tiktok::Client.new(token: token)
      end

      # GET /api/seller/202309/shops/get_active
      # Scope: seller.shop.info
      #
      # Retrieves all active shops belonging to a seller. Check activation status.
      # Used after OAuth to capture shop_cipher and shop name.
      def list
        @client.get("/api/seller/202309/shops/get_active")
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
