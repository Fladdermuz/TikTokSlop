# TAP (TikTok Affiliate Partner) campaign management — partner.tap_campaign.write + .read scopes.
#
# Real endpoints from TikTok Partner Center:
#   Write (partner.tap_campaign.write):
#     - Create Affiliate Partner Campaign (POST)
#     - Publish Affiliate Partner Campaign (POST)
#   Read (partner.tap_campaign.read):
#     - Get Affiliate Partner Campaign Detail (POST)
#     - Get Affiliate Partner Campaign List (POST)
#     - Get Affiliate Partner Campaign Product List (POST)
#     - Get Affiliate Campaign Creator Fulfillment Status Info (POST)
#     - Get Affiliate Campaign Creator Fulfillment Status List (POST)
#     - Get Affiliate Campaign Creator Product Content Statistics (POST)
#     - Get Affiliate Campaign Creator Product Sample Status (POST)
#     - Search Tap Affiliate Orders (POST) — deprecating 2026-06-30
module Tiktok
  module Resources
    class TapCampaign
      ENDPOINT_VERSION = "202405".freeze

      def initialize(token:, shop_cipher:)
        @token = token
        @shop_cipher = shop_cipher
        @client = Tiktok::Client.new(token: token)
      end

      # POST /api/affiliate_partner/202405/campaigns/create
      # Scope: partner.tap_campaign.write
      #
      # Create a new affiliate partner campaign.
      #
      # @param attrs [Hash] campaign attributes (name, description, products, commission, etc.)
      # @return [String] campaign_id
      def create(**attrs)
        body = @client.post(
          "/api/affiliate_partner/#{ENDPOINT_VERSION}/campaigns/create",
          attrs,
          shop_cipher: @shop_cipher
        )
        body.dig("data", "campaign_id") || body.dig("data", "id")
      end

      # POST /api/affiliate_partner/202405/campaigns/publish
      # Scope: partner.tap_campaign.write
      #
      # Publish a draft campaign to make it live.
      #
      # @param campaign_id [String]
      # @return [Hash] raw response
      def publish(campaign_id:)
        @client.post(
          "/api/affiliate_partner/#{ENDPOINT_VERSION}/campaigns/publish",
          { campaign_id: campaign_id },
          shop_cipher: @shop_cipher
        )
      end

      # POST /api/affiliate_partner/202405/campaigns/get
      # Scope: partner.tap_campaign.read
      #
      # Get campaign details.
      #
      # @param campaign_id [String]
      # @return [Hash] raw response with campaign details
      def find(campaign_id)
        @client.post(
          "/api/affiliate_partner/#{ENDPOINT_VERSION}/campaigns/get",
          { campaign_id: campaign_id },
          shop_cipher: @shop_cipher
        )
      end

      # POST /api/affiliate_partner/202405/campaigns/list
      # Scope: partner.tap_campaign.read
      #
      # List campaigns created by the affiliate partner.
      #
      # @param page_size [Integer]
      # @param page_token [String, nil]
      # @return [Hash] raw response with campaign list
      def list(page_size: 20, page_token: nil)
        body = { page_size: page_size }
        body[:page_token] = page_token if page_token.present?

        @client.post(
          "/api/affiliate_partner/#{ENDPOINT_VERSION}/campaigns/list",
          body,
          shop_cipher: @shop_cipher
        )
      end

      # POST /api/affiliate_partner/202405/campaigns/products/list
      # Scope: partner.tap_campaign.read
      #
      # List products submitted by sellers in a campaign.
      #
      # @param campaign_id [String]
      # @param page_size [Integer]
      # @param page_token [String, nil]
      # @return [Hash] raw response with product list
      def list_products(campaign_id:, page_size: 20, page_token: nil)
        body = { campaign_id: campaign_id, page_size: page_size }
        body[:page_token] = page_token if page_token.present?

        @client.post(
          "/api/affiliate_partner/#{ENDPOINT_VERSION}/campaigns/products/list",
          body,
          shop_cipher: @shop_cipher
        )
      end

      # POST /api/affiliate_partner/202405/campaigns/creators/fulfillment/get
      # Scope: partner.tap_campaign.read
      #
      # Get creator fulfillment status for a campaign.
      #
      # @param campaign_id [String]
      # @param creator_id [String]
      # @return [Hash] raw response
      def creator_fulfillment(campaign_id:, creator_id:)
        @client.post(
          "/api/affiliate_partner/#{ENDPOINT_VERSION}/campaigns/creators/fulfillment/get",
          { campaign_id: campaign_id, creator_id: creator_id },
          shop_cipher: @shop_cipher
        )
      end
    end
  end
end
