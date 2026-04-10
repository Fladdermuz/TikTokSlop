# Affiliate messaging — seller.affiliate_messages.write scope.
#
# Real endpoints from TikTok Partner Center:
#   - Create Conversation with Creator (POST) — get existing or create new conversation
#   - Send IM Message (POST) — send an instant message to a creator
#   - Get Conversation List (POST) — list conversations
#   - Get Message in the Conversation (POST) — chat history for one conversation
#   - Get Latest Unread Messages (POST) — unread messages from the last minute
#   - Mark Conversation Read (POST)
#   - Upload Message Image (POST)
module Tiktok
  module Resources
    class Message
      ENDPOINT_VERSION = "202405".freeze

      def initialize(token:, shop_cipher:)
        @token = token
        @shop_cipher = shop_cipher
        @client = Tiktok::Client.new(token: token)
      end

      # POST /api/affiliate_seller/202405/conversations/create
      # Scope: seller.affiliate_messages.write
      #
      # Get existing or create new conversation with a TikTok creator.
      #
      # @param creator_id [String] TikTok creator ID
      # @return [String] conversation_id
      def create_conversation(creator_id:)
        body = @client.post(
          "/api/affiliate_seller/#{ENDPOINT_VERSION}/conversations/create",
          { creator_id: creator_id },
          shop_cipher: @shop_cipher
        )
        body.dig("data", "conversation_id") || body.dig("data", "id")
      end

      # POST /api/affiliate_seller/202405/messages/send
      # Scope: seller.affiliate_messages.write
      #
      # Send an instant message to a creator in an existing conversation.
      #
      # @param conversation_id [String]
      # @param content [String] message text
      # @param message_type [String] e.g. "text", "image"
      # @return [String] message_id
      def send_message(conversation_id:, content:, message_type: "text")
        body = @client.post(
          "/api/affiliate_seller/#{ENDPOINT_VERSION}/messages/send",
          {
            conversation_id: conversation_id,
            content: content,
            message_type: message_type
          },
          shop_cipher: @shop_cipher
        )
        body.dig("data", "message_id") || body.dig("data", "id")
      end

      # POST /api/affiliate_seller/202405/conversations/list
      # Scope: seller.affiliate_messages.write
      #
      # List user's conversations.
      #
      # @param page_size [Integer]
      # @param page_token [String, nil]
      # @return [Hash] raw response with conversation list
      def list_conversations(page_size: 20, page_token: nil)
        body = { page_size: page_size }
        body[:page_token] = page_token if page_token.present?

        @client.post(
          "/api/affiliate_seller/#{ENDPOINT_VERSION}/conversations/list",
          body,
          shop_cipher: @shop_cipher
        )
      end

      # POST /api/affiliate_seller/202405/conversations/messages/get
      # Scope: seller.affiliate_messages.write
      #
      # Get chat history for one conversation.
      #
      # @param conversation_id [String]
      # @param page_size [Integer]
      # @param page_token [String, nil]
      # @return [Hash] raw response with message list
      def get_messages(conversation_id:, page_size: 20, page_token: nil)
        body = { conversation_id: conversation_id, page_size: page_size }
        body[:page_token] = page_token if page_token.present?

        @client.post(
          "/api/affiliate_seller/#{ENDPOINT_VERSION}/conversations/messages/get",
          body,
          shop_cipher: @shop_cipher
        )
      end

      # POST /api/affiliate_seller/202405/conversations/read
      # Scope: seller.affiliate_messages.write
      #
      # Mark messages in specified conversations as read.
      #
      # @param conversation_ids [Array<String>]
      # @return [Hash] raw response
      def mark_read(conversation_ids:)
        @client.post(
          "/api/affiliate_seller/#{ENDPOINT_VERSION}/conversations/read",
          { conversation_ids: Array(conversation_ids) },
          shop_cipher: @shop_cipher
        )
      end
    end
  end
end
