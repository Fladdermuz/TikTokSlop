# Creator affiliate collaboration history — creator.affiliate_collaboration.read scope.
#
# Real endpoints from TikTok Creator Marketplace API:
#   Read (creator.affiliate_collaboration.read):
#     - Search Creator Collaborations (POST) — list all collabs a creator has participated in
#     - Get Creator Collaboration Detail (POST) — full detail for a single collab record
#
# This scope is distinct from seller.affiliate_collaboration.read (which is the seller side).
# creator.affiliate_collaboration.read lets a seller read the collaboration history
# on the *creator* side — i.e., all sellers and products the creator has worked with,
# commission rates, status, and performance metrics.
module Tiktok
  module Resources
    class CreatorCollaboration
      ENDPOINT_VERSION = "202405".freeze

      def initialize(token:, shop_cipher:)
        @token = token
        @shop_cipher = shop_cipher
        @client = Tiktok::Client.new(token: token)
      end

      # POST /api/creator/202405/affiliate_collaborations/search
      # Scope: creator.affiliate_collaboration.read
      #
      # Search a creator's full collaboration history across all sellers.
      # Returns completed, active, and expired collab records including
      # the seller name, product, commission rate, and content performance.
      #
      # @param creator_id [String]    TikTok external creator ID
      # @param filters [Hash]         optional: { status:, start_time:, end_time:, page_size:, page_token: }
      # @return [Hash] raw response with collaboration list and next_page_token
      def search(creator_id:, filters: {})
        @client.post(
          "/api/creator/#{ENDPOINT_VERSION}/affiliate_collaborations/search",
          { creator_id: creator_id }.merge(filters),
          shop_cipher: @shop_cipher
        )
      end

      # POST /api/creator/202405/affiliate_collaborations/get
      # Scope: creator.affiliate_collaboration.read
      #
      # Retrieve full detail for a single collaboration record, including
      # content views, sales conversions, and timeline.
      #
      # @param creator_id [String]        TikTok external creator ID
      # @param collaboration_id [String]  the collab record to fetch
      # @return [Hash] raw collaboration detail
      def find(creator_id:, collaboration_id:)
        @client.post(
          "/api/creator/#{ENDPOINT_VERSION}/affiliate_collaborations/get",
          { creator_id: creator_id, collaboration_id: collaboration_id },
          shop_cipher: @shop_cipher
        )
      end

      # Parse a raw collaboration hash from the API into a typed struct.
      #
      # @param hash [Hash] single collab entry from the API response
      # @return [CollaborationRecord]
      def self.parse(hash)
        CollaborationRecord.from_api(hash)
      end

      CollaborationRecord = Data.define(
        :collaboration_id,
        :seller_name,
        :product_name,
        :commission_rate,
        :status,
        :start_date,
        :end_date,
        :content_views,
        :raw
      ) do
        def self.from_api(hash)
          new(
            collaboration_id: hash["collaboration_id"] || hash["id"],
            seller_name:      hash["seller_name"] || hash["shop_name"],
            product_name:     hash["product_name"] || hash.dig("product", "name"),
            commission_rate:  hash["commission_rate"].to_f,
            status:           hash["status"]&.downcase || "completed",
            start_date:       parse_date(hash["start_time"] || hash["start_date"]),
            end_date:         parse_date(hash["end_time"] || hash["end_date"]),
            content_views:    hash["content_views"].to_i,
            raw:              hash
          )
        end

        def self.parse_date(value)
          return nil if value.blank?
          value.is_a?(Integer) ? Time.at(value).to_date : Date.parse(value.to_s)
        rescue ArgumentError
          nil
        end

        def commission_percent
          (commission_rate * 100).round(1)
        end
      end
    end
  end
end
