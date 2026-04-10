# Webhook management — seller.authorization.info scope.
#
# Real endpoints from TikTok Partner Center:
#   - Update Shop Webhook — register or update a webhook URL for one or more event topics
#   - Get Shop Webhooks — list current webhook configurations
#   - Delete Shop Webhook — remove a webhook subscription
module Tiktok
  module Resources
    class Webhook
      ENDPOINT_VERSION = "202309".freeze

      def initialize(token:, shop_cipher:)
        @token = token
        @shop_cipher = shop_cipher
        @client = Tiktok::Client.new(token: token)
      end

      # POST /api/seller/202309/webhooks/update
      # Scope: seller.authorization.info
      #
      # Register or update a webhook URL for one or more event topics.
      # Calling this again with the same address overwrites the topic list.
      #
      # @param address  [String]        HTTPS URL TikTok will POST events to
      # @param topics   [Array<String>] event topic strings, e.g.
      #                                 ["ORDER_STATUS_CHANGED", "COLLABORATION_STATUS_CHANGED"]
      # @return [Hash] raw response
      def update(address:, topics:)
        @client.post(
          "/api/seller/#{ENDPOINT_VERSION}/webhooks/update",
          { address: address, topics: topics },
          shop_cipher: @shop_cipher
        )
      end

      # GET /api/seller/202309/webhooks/get
      # Scope: seller.authorization.info
      #
      # List current webhook subscriptions for the shop.
      #
      # @return [Hash] raw response with webhook list
      def list
        @client.get(
          "/api/seller/#{ENDPOINT_VERSION}/webhooks/get",
          { shop_cipher: @shop_cipher }
        )
      end

      # POST /api/seller/202309/webhooks/delete
      # Scope: seller.authorization.info
      #
      # Remove a webhook subscription by topic or address.
      #
      # @param address [String]        webhook URL to delete
      # @param topics  [Array<String>] specific topics to unsubscribe (omit to remove all for the address)
      # @return [Hash] raw response
      def delete(address:, topics: [])
        body = { address: address }
        body[:topics] = topics if topics.any?
        @client.post(
          "/api/seller/#{ENDPOINT_VERSION}/webhooks/delete",
          body,
          shop_cipher: @shop_cipher
        )
      end
    end
  end
end
