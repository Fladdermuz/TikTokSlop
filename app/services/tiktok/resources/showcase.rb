# Creator showcase products — creator.showcase.read scope.
#
# Real endpoints from TikTok Creator Marketplace API:
#   - Read Showcase Products (GET)
#
# The showcase endpoint returns products a creator is actively promoting
# in their TikTok Shop storefront.
module Tiktok
  module Resources
    class Showcase
      ENDPOINT_VERSION = "202405".freeze

      def initialize(token:, shop_cipher:)
        @token = token
        @shop_cipher = shop_cipher
        @client = Tiktok::Client.new(token: token)
      end

      # GET /api/creator/202405/showcase/products
      # Scope: creator.showcase.read
      #
      # Read the list of products a creator is showcasing on their storefront.
      #
      # @param creator_id [String] TikTok creator ID
      # @return [Array<ShowcaseProduct>]
      def read_showcase(creator_id:)
        body = @client.get(
          "/api/creator/#{ENDPOINT_VERSION}/showcase/products",
          { creator_id: creator_id },
          shop_cipher: @shop_cipher
        )

        Array(body.dig("data", "products")).map { |p| ShowcaseProduct.from_api(p) }
      end

      ShowcaseProduct = Data.define(:product_id, :name, :image_url, :price_cents, :currency, :category, :brand, :raw) do
        def self.from_api(hash)
          new(
            product_id: hash["product_id"],
            name:       hash["name"],
            image_url:  hash["cover_url"] || hash["image_url"],
            price_cents: ((hash["price"] || 0).to_f * 100).to_i,
            currency:   hash["currency"] || "USD",
            category:   hash["category_name"],
            brand:      hash["brand_name"],
            raw:        hash
          )
        end

        def price_dollars
          price_cents.to_f / 100
        end
      end
    end
  end
end
