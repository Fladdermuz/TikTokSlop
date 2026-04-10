# Targeted collaboration creation — the core "send invite" endpoint.
module Tiktok
  module Resources
    class AffiliateCollaboration
      ENDPOINT_VERSION = "202405".freeze

      def initialize(token:, shop_cipher:)
        @token = token
        @shop_cipher = shop_cipher
        @client = Tiktok::Client.new(token: token)
      end

      # POST /api/affiliate_seller/202405/targeted_collaborations
      #
      # @param creator_id [String]      TikTok external creator ID
      # @param product_id [String]      TikTok product SKU
      # @param commission_rate [Float]  0.0–1.0
      # @param message [String]         personalized invite message
      # @param sample_offer [Boolean]
      # @return [String] external collaboration ID
      def create_targeted(creator_id:, product_id:, commission_rate:, message:, sample_offer: false)
        body = @client.post(
          "/api/affiliate_seller/#{ENDPOINT_VERSION}/targeted_collaborations",
          {
            creator_id:      creator_id,
            product_id:      product_id,
            commission_rate: commission_rate,
            message:         message,
            with_sample:     sample_offer
          },
          shop_cipher: @shop_cipher
        )
        body.dig("data", "collaboration_id") || body.dig("data", "id")
      end

      # GET /api/affiliate_seller/202405/targeted_collaborations/{id}
      def find(collaboration_id)
        @client.get(
          "/api/affiliate_seller/#{ENDPOINT_VERSION}/targeted_collaborations/#{collaboration_id}",
          shop_cipher: @shop_cipher
        )
      end

      # DELETE /api/affiliate_seller/202405/targeted_collaborations/{id}
      def cancel(collaboration_id)
        @client.delete(
          "/api/affiliate_seller/#{ENDPOINT_VERSION}/targeted_collaborations/#{collaboration_id}",
          shop_cipher: @shop_cipher
        )
      end
    end
  end
end
