# Affiliate creator search and detail.
#
# Endpoint paths and request shapes are stubbed against the published affiliate
# API conventions; exact paths will be confirmed once we have an approved app
# in Partner Center. Update docs/TIKTOK_API_NOTES.md as the schema is verified.
module Tiktok
  module Resources
    class AffiliateCreator
      ENDPOINT_VERSION = "202405".freeze

      def initialize(token:, shop_cipher:)
        @token = token
        @shop_cipher = shop_cipher
        @client = Tiktok::Client.new(token: token)
      end

      # POST /api/affiliate_creator/202405/creators/search
      #
      # @param filters [Hash] {
      #   min_gmv_cents:, max_gmv_cents:, gmv_tier:,
      #   min_followers:, max_followers:,
      #   categories: [..], country:, keyword:,
      #   sort: "gmv_desc"|"followers_desc"|"engagement_desc",
      #   page_size:, page_token:
      # }
      # @return [Array<Tiktok::Types::Creator>]
      def search(filters: {})
        body = @client.post(
          "/api/affiliate_creator/#{ENDPOINT_VERSION}/creators/search",
          to_request_body(filters),
          shop_cipher: @shop_cipher
        )

        creators = Array(body.dig("data", "creators")).map { |c| Tiktok::Types::Creator.from_api(c) }
        SearchResult.new(creators: creators, next_page_token: body.dig("data", "next_page_token"), raw: body)
      end

      # GET /api/affiliate_creator/202405/creators/{creator_id}
      def find(external_id)
        body = @client.get(
          "/api/affiliate_creator/#{ENDPOINT_VERSION}/creators/#{external_id}",
          shop_cipher: @shop_cipher
        )
        Tiktok::Types::Creator.from_api(body["data"] || {})
      end

      private

      def to_request_body(filters)
        body = {}
        body[:gmv_min] = (filters[:min_gmv_cents].to_f / 100).round(2) if filters[:min_gmv_cents]
        body[:gmv_max] = (filters[:max_gmv_cents].to_f / 100).round(2) if filters[:max_gmv_cents]
        body[:gmv_tier] = filters[:gmv_tier] if filters[:gmv_tier].present?
        body[:follower_min] = filters[:min_followers] if filters[:min_followers]
        body[:follower_max] = filters[:max_followers] if filters[:max_followers]
        body[:categories]   = Array(filters[:categories]) if filters[:categories].present?
        body[:country_code] = filters[:country] if filters[:country].present?
        body[:keyword]      = filters[:keyword] if filters[:keyword].present?
        body[:sort]         = filters[:sort] || "gmv_desc"
        body[:page_size]    = filters[:page_size] || 50
        body[:page_token]   = filters[:page_token] if filters[:page_token].present?
        body
      end

      SearchResult = Data.define(:creators, :next_page_token, :raw)
    end
  end
end
