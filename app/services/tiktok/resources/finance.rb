# Finance data access — seller.finance.info scope.
#
# Real endpoints from TikTok Partner Center (new API only, no legacy):
#   - Get Payments (GET) — payment records by date range
#   - Get Statements (GET) — daily statements by date range or payment status
#   - Get Transactions by Order (GET) — order + SKU level transactions (US/UK only)
#   - Get Transactions by Statement (GET) — transactions by statement_id (US/UK only)
#   - Get Unsettled Transactions (GET) — unsettled orders/adjustments (after 2025-01-01)
#   - Get Withdrawals (GET) — withdrawal records by date range
module Tiktok
  module Resources
    class Finance
      ENDPOINT_VERSION = "202309".freeze

      def initialize(token:, shop_cipher:)
        @token = token
        @shop_cipher = shop_cipher
        @client = Tiktok::Client.new(token: token)
      end

      # GET /api/finance/202309/payments
      # Scope: seller.finance.info
      #
      # Retrieve payment records for the shop within a date range.
      #
      # @param start_date [String] ISO date string, e.g. "2024-01-01"
      # @param end_date   [String] ISO date string, e.g. "2024-01-31"
      # @param page_size  [Integer] records per page (default 20, max 100)
      # @param page_token [String, nil] cursor for pagination
      # @return [Hash] raw response with payment list and next_page_token
      def payments(start_date:, end_date:, page_size: 20, page_token: nil)
        params = { start_date: start_date, end_date: end_date, page_size: page_size }
        params[:page_token] = page_token if page_token.present?
        @client.get(
          "/api/finance/#{ENDPOINT_VERSION}/payments",
          shop_cipher: @shop_cipher,
          params: params
        )
      end

      # GET /api/finance/202309/statements
      # Scope: seller.finance.info
      #
      # Retrieve daily settlement statements, filterable by date range or payment status.
      #
      # @param start_date      [String, nil] ISO date string
      # @param end_date        [String, nil] ISO date string
      # @param payment_status  [String, nil] e.g. "PAID", "PENDING"
      # @param page_size       [Integer]
      # @param page_token      [String, nil]
      # @return [Hash] raw response with statement list and next_page_token
      def statements(start_date: nil, end_date: nil, payment_status: nil, page_size: 20, page_token: nil)
        params = { page_size: page_size }
        params[:start_date]     = start_date     if start_date.present?
        params[:end_date]       = end_date       if end_date.present?
        params[:payment_status] = payment_status if payment_status.present?
        params[:page_token]     = page_token     if page_token.present?
        @client.get(
          "/api/finance/#{ENDPOINT_VERSION}/statements",
          shop_cipher: @shop_cipher,
          params: params
        )
      end

      # GET /api/finance/202309/transactions/order
      # Scope: seller.finance.info
      # Region: US, UK only
      #
      # Retrieve order- and SKU-level transaction records within a date range.
      #
      # @param start_date [String] ISO date string
      # @param end_date   [String] ISO date string
      # @param page_size  [Integer]
      # @param page_token [String, nil]
      # @return [Hash] raw response with transaction list and next_page_token
      def transactions_by_order(start_date:, end_date:, page_size: 20, page_token: nil)
        params = { start_date: start_date, end_date: end_date, page_size: page_size }
        params[:page_token] = page_token if page_token.present?
        @client.get(
          "/api/finance/#{ENDPOINT_VERSION}/transactions/order",
          shop_cipher: @shop_cipher,
          params: params
        )
      end

      # GET /api/finance/202309/transactions/statement
      # Scope: seller.finance.info
      # Region: US, UK only
      #
      # Retrieve all transactions belonging to a specific statement.
      #
      # @param statement_id [String] the statement ID to look up
      # @param page_size    [Integer]
      # @param page_token   [String, nil]
      # @return [Hash] raw response with transaction list and next_page_token
      def transactions_by_statement(statement_id:, page_size: 20, page_token: nil)
        params = { statement_id: statement_id, page_size: page_size }
        params[:page_token] = page_token if page_token.present?
        @client.get(
          "/api/finance/#{ENDPOINT_VERSION}/transactions/statement",
          shop_cipher: @shop_cipher,
          params: params
        )
      end

      # GET /api/finance/202309/transactions/unsettled
      # Scope: seller.finance.info
      #
      # Retrieve unsettled order and adjustment transactions.
      # Only covers activity after 2025-01-01.
      #
      # @param page_size  [Integer]
      # @param page_token [String, nil]
      # @return [Hash] raw response with unsettled transaction list and next_page_token
      def unsettled_transactions(page_size: 20, page_token: nil)
        params = { page_size: page_size }
        params[:page_token] = page_token if page_token.present?
        @client.get(
          "/api/finance/#{ENDPOINT_VERSION}/transactions/unsettled",
          shop_cipher: @shop_cipher,
          params: params
        )
      end

      # GET /api/finance/202309/withdrawals
      # Scope: seller.finance.info
      #
      # Retrieve withdrawal records for the shop within a date range.
      #
      # @param start_date [String] ISO date string
      # @param end_date   [String] ISO date string
      # @param page_size  [Integer]
      # @param page_token [String, nil]
      # @return [Hash] raw response with withdrawal list and next_page_token
      def withdrawals(start_date:, end_date:, page_size: 20, page_token: nil)
        params = { start_date: start_date, end_date: end_date, page_size: page_size }
        params[:page_token] = page_token if page_token.present?
        @client.get(
          "/api/finance/#{ENDPOINT_VERSION}/withdrawals",
          shop_cipher: @shop_cipher,
          params: params
        )
      end
    end
  end
end
