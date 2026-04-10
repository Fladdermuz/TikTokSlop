# Targeted collaboration management — seller.affiliate_collaboration.write + .read scopes.
#
# Real endpoints from TikTok Partner Center:
#   Write (seller.affiliate_collaboration.write):
#     - Create Target Collaboration (POST)
#     - Update Target Collaboration (POST)
#     - Remove Target Collaboration (POST)
#     - Generate Target Collaboration Link (POST)
#   Read (seller.affiliate_collaboration.read):
#     - Search Target Collaborations (POST)
#     - Query Target Collaboration Detail (POST)
module Tiktok
  module Resources
    class AffiliateCollaboration
      ENDPOINT_VERSION = "202405".freeze

      def initialize(token:, shop_cipher:)
        @token = token
        @shop_cipher = shop_cipher
        @client = Tiktok::Client.new(token: token)
      end

      # POST /api/affiliate_seller/202405/target_collaborations/create
      # Scope: seller.affiliate_collaboration.write
      #
      # Create private collab with specific products + commission + invited creators.
      # Not visible in Creator Marketplace, only to invited creators.
      #
      # @param creator_id [String]      TikTok external creator ID
      # @param product_id [String]      TikTok product SKU
      # @param commission_rate [Float]  0.0–1.0
      # @param message [String]         personalized invite message
      # @param sample_offer [Boolean]
      # @return [String] external collaboration ID
      def create_targeted(creator_id:, product_id:, commission_rate:, message:, sample_offer: false)
        body = @client.post(
          "/api/affiliate_seller/#{ENDPOINT_VERSION}/target_collaborations/create",
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

      # POST /api/affiliate_seller/202405/target_collaborations/search
      # Scope: seller.affiliate_collaboration.read
      #
      # Search existing target collaborations by name, ID, product, creator.
      #
      # @param filters [Hash] search criteria
      # @return [Hash] raw response with collaboration list
      def search(filters: {})
        @client.post(
          "/api/affiliate_seller/#{ENDPOINT_VERSION}/target_collaborations/search",
          filters,
          shop_cipher: @shop_cipher
        )
      end

      # POST /api/affiliate_seller/202405/target_collaborations/get
      # Scope: seller.affiliate_collaboration.read
      #
      # Get target collaboration detail.
      #
      # @param collaboration_id [String]
      # @return [Hash] raw collaboration detail
      def find(collaboration_id)
        @client.post(
          "/api/affiliate_seller/#{ENDPOINT_VERSION}/target_collaborations/get",
          { collaboration_id: collaboration_id },
          shop_cipher: @shop_cipher
        )
      end

      # POST /api/affiliate_seller/202405/target_collaborations/update
      # Scope: seller.affiliate_collaboration.write
      #
      # Update a standard target collaboration.
      #
      # @param collaboration_id [String]
      # @param attrs [Hash] fields to update
      # @return [Hash] raw response
      def update(collaboration_id:, **attrs)
        @client.post(
          "/api/affiliate_seller/#{ENDPOINT_VERSION}/target_collaborations/update",
          { collaboration_id: collaboration_id }.merge(attrs),
          shop_cipher: @shop_cipher
        )
      end

      # POST /api/affiliate_seller/202405/target_collaborations/remove
      # Scope: seller.affiliate_collaboration.write
      #
      # Seller removes a target collaboration.
      #
      # @param collaboration_id [String]
      # @return [Hash] raw response
      def cancel(collaboration_id)
        @client.post(
          "/api/affiliate_seller/#{ENDPOINT_VERSION}/target_collaborations/remove",
          { collaboration_id: collaboration_id },
          shop_cipher: @shop_cipher
        )
      end

      # POST /api/affiliate_seller/202405/target_collaborations/link/generate
      # Scope: seller.affiliate_collaboration.write
      #
      # Generate shareable link for creator to review and accept a target collaboration.
      #
      # @param collaboration_id [String]
      # @return [String] shareable URL
      def generate_link(collaboration_id:)
        body = @client.post(
          "/api/affiliate_seller/#{ENDPOINT_VERSION}/target_collaborations/link/generate",
          { collaboration_id: collaboration_id },
          shop_cipher: @shop_cipher
        )
        body.dig("data", "link") || body.dig("data", "url")
      end
    end
  end
end
