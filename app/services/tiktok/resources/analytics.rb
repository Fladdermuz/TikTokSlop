# Shop analytics — data.shop_analytics.public.read scope.
#
# Real endpoints from TikTok Partner Center:
#   - Get Shop Performance — seller/shop level metrics
#   - Get Shop Performance Per Hour — hourly breakdown (within 30 days)
#   - Get Shop Product Performance List — paginated product metrics
#   - Get Shop Product Performance Detail — single product metrics
#   - Get Shop Video Performance List — video list with metrics
#   - Get Shop Video Performance Details — single video metrics
#   - Get Shop Video Performance Overview — overall video stats
module Tiktok
  module Resources
    class Analytics
      ENDPOINT_VERSION = "202405".freeze

      def initialize(token:, shop_cipher:)
        @token = token
        @shop_cipher = shop_cipher
        @client = Tiktok::Client.new(token: token)
      end

      # POST /api/shop_analytics/202405/performance/shop/query
      # Scope: data.shop_analytics.public.read
      #
      # Retrieve seller/shop level aggregate metrics for a date range.
      #
      # @param start_date [String] "YYYY-MM-DD"
      # @param end_date   [String] "YYYY-MM-DD"
      # @param metrics    [Array<String>] list of metric names to return
      # @return [Hash] raw response with shop performance metrics
      def shop_performance(start_date:, end_date:, metrics: [])
        body = { start_date: start_date, end_date: end_date }
        body[:metrics] = metrics if metrics.any?
        @client.post(
          "/api/shop_analytics/#{ENDPOINT_VERSION}/performance/shop/query",
          body,
          shop_cipher: @shop_cipher
        )
      end

      # POST /api/shop_analytics/202405/performance/shop/hourly/query
      # Scope: data.shop_analytics.public.read
      #
      # Retrieve hourly breakdown of shop metrics. Date range must be within
      # the last 30 days.
      #
      # @param start_date [String] "YYYY-MM-DD"
      # @param end_date   [String] "YYYY-MM-DD"
      # @param metrics    [Array<String>] list of metric names to return
      # @return [Hash] raw response with hourly performance data
      def shop_performance_per_hour(start_date:, end_date:, metrics: [])
        body = { start_date: start_date, end_date: end_date }
        body[:metrics] = metrics if metrics.any?
        @client.post(
          "/api/shop_analytics/#{ENDPOINT_VERSION}/performance/shop/hourly/query",
          body,
          shop_cipher: @shop_cipher
        )
      end

      # POST /api/shop_analytics/202405/performance/product/list/query
      # Scope: data.shop_analytics.public.read
      #
      # List product-level performance metrics, paginated.
      #
      # @param start_date [String] "YYYY-MM-DD"
      # @param end_date   [String] "YYYY-MM-DD"
      # @param metrics    [Array<String>] metric names to return
      # @param page_size  [Integer] results per page (default 20)
      # @param page_token [String] pagination cursor
      # @param filters    [Hash] additional filter fields (e.g. product_id:)
      # @return [Hash] raw response with product list and next_page_token
      def product_performance_list(start_date:, end_date:, metrics: [], page_size: 20, page_token: nil, filters: {})
        body = { start_date: start_date, end_date: end_date, page_size: page_size }
        body[:metrics]    = metrics    if metrics.any?
        body[:page_token] = page_token if page_token.present?
        body.merge!(filters)
        @client.post(
          "/api/shop_analytics/#{ENDPOINT_VERSION}/performance/product/list/query",
          body,
          shop_cipher: @shop_cipher
        )
      end

      # POST /api/shop_analytics/202405/performance/product/detail/query
      # Scope: data.shop_analytics.public.read
      #
      # Retrieve metrics for a single product.
      #
      # @param product_id [String] TikTok product ID
      # @param start_date [String] "YYYY-MM-DD"
      # @param end_date   [String] "YYYY-MM-DD"
      # @param metrics    [Array<String>] metric names to return
      # @return [Hash] raw response with product detail metrics
      def product_performance_detail(product_id:, start_date:, end_date:, metrics: [])
        body = { product_id: product_id, start_date: start_date, end_date: end_date }
        body[:metrics] = metrics if metrics.any?
        @client.post(
          "/api/shop_analytics/#{ENDPOINT_VERSION}/performance/product/detail/query",
          body,
          shop_cipher: @shop_cipher
        )
      end

      # POST /api/shop_analytics/202405/performance/video/list/query
      # Scope: data.shop_analytics.public.read
      #
      # List video-level performance metrics, paginated.
      #
      # @param start_date [String] "YYYY-MM-DD"
      # @param end_date   [String] "YYYY-MM-DD"
      # @param metrics    [Array<String>] metric names to return
      # @param page_size  [Integer] results per page (default 20)
      # @param page_token [String] pagination cursor
      # @param filters    [Hash] additional filter fields
      # @return [Hash] raw response with video list and next_page_token
      def video_performance_list(start_date:, end_date:, metrics: [], page_size: 20, page_token: nil, filters: {})
        body = { start_date: start_date, end_date: end_date, page_size: page_size }
        body[:metrics]    = metrics    if metrics.any?
        body[:page_token] = page_token if page_token.present?
        body.merge!(filters)
        @client.post(
          "/api/shop_analytics/#{ENDPOINT_VERSION}/performance/video/list/query",
          body,
          shop_cipher: @shop_cipher
        )
      end

      # POST /api/shop_analytics/202405/performance/video/detail/query
      # Scope: data.shop_analytics.public.read
      #
      # Retrieve metrics for a single video.
      #
      # @param video_id   [String] TikTok video ID
      # @param start_date [String] "YYYY-MM-DD"
      # @param end_date   [String] "YYYY-MM-DD"
      # @param metrics    [Array<String>] metric names to return
      # @return [Hash] raw response with video detail metrics
      def video_performance_detail(video_id:, start_date:, end_date:, metrics: [])
        body = { video_id: video_id, start_date: start_date, end_date: end_date }
        body[:metrics] = metrics if metrics.any?
        @client.post(
          "/api/shop_analytics/#{ENDPOINT_VERSION}/performance/video/detail/query",
          body,
          shop_cipher: @shop_cipher
        )
      end

      # POST /api/shop_analytics/202405/performance/video/overview/query
      # Scope: data.shop_analytics.public.read
      #
      # Retrieve overall video performance overview metrics for the shop.
      #
      # @param start_date [String] "YYYY-MM-DD"
      # @param end_date   [String] "YYYY-MM-DD"
      # @param metrics    [Array<String>] metric names to return
      # @return [Hash] raw response with overall video stats
      def video_performance_overview(start_date:, end_date:, metrics: [])
        body = { start_date: start_date, end_date: end_date }
        body[:metrics] = metrics if metrics.any?
        @client.post(
          "/api/shop_analytics/#{ENDPOINT_VERSION}/performance/video/overview/query",
          body,
          shop_cipher: @shop_cipher
        )
      end
    end
  end
end
