# Sample order creation and status tracking.
module Tiktok
  module Resources
    class AffiliateSample
      ENDPOINT_VERSION = "202405".freeze

      def initialize(token:, shop_cipher:)
        @token = token
        @shop_cipher = shop_cipher
        @client = Tiktok::Client.new(token: token)
      end

      # POST /api/affiliate_seller/202405/samples
      def create(creator_id:, product_id:, collaboration_id: nil, shipping_address: nil)
        body = @client.post(
          "/api/affiliate_seller/#{ENDPOINT_VERSION}/samples",
          {
            creator_id:        creator_id,
            product_id:        product_id,
            collaboration_id:  collaboration_id,
            shipping_address:  shipping_address
          }.compact,
          shop_cipher: @shop_cipher
        )
        body.dig("data", "sample_id") || body.dig("data", "id")
      end

      # GET /api/affiliate_seller/202405/samples/{id}
      def find(sample_id)
        @client.get(
          "/api/affiliate_seller/#{ENDPOINT_VERSION}/samples/#{sample_id}",
          shop_cipher: @shop_cipher
        )
      end
    end
  end
end
