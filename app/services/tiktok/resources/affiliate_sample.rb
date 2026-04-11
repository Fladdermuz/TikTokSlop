# Sample application search and fulfillment tracking — seller.affiliate_collaboration.read scope.
#
# Real endpoints from TikTok Partner Center:
#   - Seller Search Sample Applications (POST)
#   - Seller Search Sample Applications Fulfillments (POST)
#   - Seller Review Sample Applications (POST) — requires .write scope
#   - Seller Get Sample Request Deeplink (POST)
#
# NOTE: The old guessed endpoints for creating samples and fetching by ID were
# wrong. The real API exposes search-based endpoints for querying sample
# applications and their fulfillment status. Sample creation happens through
# the collaboration flow (Create Target Collaboration with with_sample: true).
module Tiktok
  module Resources
    class AffiliateSample
      ENDPOINT_VERSION = "202405".freeze

      def initialize(token:, shop_cipher:)
        @token = token
        @shop_cipher = shop_cipher
        @client = Tiktok::Client.new(token: token)
      end

      # POST /api/affiliate_seller/202405/sample_applications/search
      # Scope: seller.affiliate_collaboration.read
      #
      # Query sample applications by product, creator, or status.
      #
      # @param filters [Hash] { product_id:, creator_id:, status:, page_size:, page_token: }
      # @return [Hash] raw response with sample application list
      def search(filters: {})
        @client.post(
          "/api/affiliate_seller/#{ENDPOINT_VERSION}/sample_applications/search",
          build_search_body(filters),
          shop_cipher: @shop_cipher
        )
      end

      # POST /api/affiliate_seller/202405/sample_applications/fulfillments/search
      # Scope: seller.affiliate_collaboration.read
      #
      # Track sample application fulfillment status and whether it resulted in orders.
      #
      # @param filters [Hash] { sample_application_id:, product_id:, status:, page_size:, page_token: }
      # @return [Hash] raw response with fulfillment list
      def search_fulfillments(filters: {})
        @client.post(
          "/api/affiliate_seller/#{ENDPOINT_VERSION}/sample_applications/fulfillments/search",
          build_search_body(filters),
          shop_cipher: @shop_cipher
        )
      end

      # POST /api/affiliate_seller/202405/sample_applications/review
      # Scope: seller.affiliate_collaboration.write
      #
      # Approve or reject creator sample requests in open collaborations.
      # Rejection requires a reason.
      #
      # @param sample_application_id [String]
      # @param action [String] "approve" or "reject"
      # @param reject_reason [String, nil] required when action is "reject"
      # @return [Hash] raw response
      def review(sample_application_id:, action:, reject_reason: nil)
        body = {
          sample_application_id: sample_application_id,
          action: action
        }
        body[:reject_reason] = reject_reason if reject_reason.present?

        @client.post(
          "/api/affiliate_seller/#{ENDPOINT_VERSION}/sample_applications/review",
          body,
          shop_cipher: @shop_cipher
        )
      end

      # POST /api/affiliate_seller/202405/sample_applications/deeplink/get
      # Scope: seller.affiliate_collaboration.read
      #
      # Get TikTok deeplink to sample request page. Can encode as QR code for email.
      #
      # @param product_id [String]
      # @return [String] deeplink URL
      def deeplink(product_id:)
        body = @client.post(
          "/api/affiliate_seller/#{ENDPOINT_VERSION}/sample_applications/deeplink/get",
          { product_id: product_id },
          shop_cipher: @shop_cipher
        )
        body.dig("data", "deeplink") || body.dig("data", "url")
      end

      # POST /api/affiliate_seller/202405/sample_applications/eligibility/check
      # Scope: seller.affiliate_collaboration.read
      #
      # Check whether a creator is eligible to receive a product sample.
      # Used as a pre-check before sending invites with sample offers.
      #
      # @param creator_id [String] TikTok external creator ID
      # @param product_id [String] TikTok external product ID
      # @return [Boolean] true if the creator can receive a sample
      def sample_eligible?(creator_id:, product_id:)
        resp = @client.post(
          "/api/affiliate_seller/#{ENDPOINT_VERSION}/sample_applications/eligibility/check",
          { creator_id: creator_id, product_id: product_id },
          shop_cipher: @shop_cipher
        )
        resp.dig("data", "eligible") == true
      rescue Tiktok::Error => e
        Rails.logger.warn("[sample_eligible?] TikTok API error for creator=#{creator_id} product=#{product_id}: #{e.message}")
        # Fail open — don't block invite on eligibility check failures
        true
      end

      private

      def build_search_body(filters)
        body = {}
        body[:product_id]             = filters[:product_id] if filters[:product_id].present?
        body[:creator_id]             = filters[:creator_id] if filters[:creator_id].present?
        body[:sample_application_id]  = filters[:sample_application_id] if filters[:sample_application_id].present?
        body[:status]                 = filters[:status] if filters[:status].present?
        body[:page_size]              = filters[:page_size] || 20
        body[:page_token]             = filters[:page_token] if filters[:page_token].present?
        body
      end
    end
  end
end
