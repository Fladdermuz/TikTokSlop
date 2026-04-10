# Product catalog access — seller.product.basic scope.
#
# Real endpoints from TikTok Partner Center:
#   - Search Products (POST) — list products by conditions
#   - Get Product (GET) — retrieve all properties of a product
module Tiktok
  module Resources
    class Product
      ENDPOINT_VERSION = "202309".freeze

      def initialize(token:, shop_cipher:)
        @token = token
        @shop_cipher = shop_cipher
        @client = Tiktok::Client.new(token: token)
      end

      # POST /api/products/202309/search
      # Scope: seller.product.basic
      #
      # List products by conditions, returns key properties.
      #
      # @param filters [Hash] { status:, keyword:, category_id:, page_size:, page_token: }
      # @return [Hash] raw response with product list
      def search(filters: {})
        @client.post(
          "/api/products/#{ENDPOINT_VERSION}/search",
          build_search_body(filters),
          shop_cipher: @shop_cipher
        )
      end

      # GET /api/products/202309/products/{product_id}
      # Scope: seller.product.basic
      #
      # Retrieve all properties of a product (except FREEZE/DELETED).
      #
      # @param product_id [String]
      # @return [Hash] raw response with product details
      def find(product_id)
        @client.get(
          "/api/products/#{ENDPOINT_VERSION}/products/#{product_id}",
          shop_cipher: @shop_cipher
        )
      end

      private

      def build_search_body(filters)
        body = {}
        body[:status]      = filters[:status] if filters[:status].present?
        body[:keyword]     = filters[:keyword] if filters[:keyword].present?
        body[:category_id] = filters[:category_id] if filters[:category_id].present?
        body[:page_size]   = filters[:page_size] || 20
        body[:page_token]  = filters[:page_token] if filters[:page_token].present?
        body
      end
    end
  end
end
