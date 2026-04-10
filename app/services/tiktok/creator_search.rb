# Local creator search.
#
# Always queries our local Creator cache (the global table). When connected to a
# real TikTok shop, also calls the TikTok API and upserts results into the cache.
#
# Returns an ActiveRecord::Relation so callers can paginate, count, etc.
module Tiktok
  class CreatorSearch
    DEFAULT_PAGE_SIZE = 50

    Filters = Data.define(
      :min_gmv_cents,
      :max_gmv_cents,
      :gmv_tier,
      :min_followers,
      :max_followers,
      :categories,
      :country,
      :keyword,
      :sort,
      :page,
      :per_page
    ) do
      def self.from_params(params)
        new(
          min_gmv_cents: params[:min_gmv_dollars].present? ? (params[:min_gmv_dollars].to_f * 100).to_i : nil,
          max_gmv_cents: params[:max_gmv_dollars].present? ? (params[:max_gmv_dollars].to_f * 100).to_i : nil,
          gmv_tier:      params[:gmv_tier].presence,
          min_followers: params[:min_followers].presence&.to_i,
          max_followers: params[:max_followers].presence&.to_i,
          categories:    Array(params[:categories]).reject(&:blank?),
          country:       params[:country].presence,
          keyword:       params[:keyword].presence,
          sort:          params[:sort].presence || "gmv_desc",
          page:          (params[:page].presence || 1).to_i,
          per_page:      (params[:per_page].presence || DEFAULT_PAGE_SIZE).to_i
        )
      end

      def to_query_params
        to_h.compact.transform_keys(&:to_s)
      end
    end

    def self.call(shop:, filters:)
      new(shop: shop, filters: filters).call
    end

    def initialize(shop:, filters:)
      @shop = shop
      @filters = filters
    end

    def call
      sync_from_tiktok_if_connected
      relation = apply_filters(Creator.all)
      relation = apply_sort(relation)
      relation = relation.limit(@filters.per_page).offset((@filters.page - 1) * @filters.per_page)
      relation
    end

    def total_count
      apply_filters(Creator.all).count
    end

    private

    def apply_filters(scope)
      scope = scope.where("gmv_cents >= ?", @filters.min_gmv_cents) if @filters.min_gmv_cents
      scope = scope.where("gmv_cents <= ?", @filters.max_gmv_cents) if @filters.max_gmv_cents
      scope = scope.where(gmv_tier: @filters.gmv_tier) if @filters.gmv_tier
      scope = scope.where("follower_count >= ?", @filters.min_followers) if @filters.min_followers
      scope = scope.where("follower_count <= ?", @filters.max_followers) if @filters.max_followers
      scope = scope.where(country: @filters.country) if @filters.country
      if @filters.categories.any?
        scope = scope.where("categories && ARRAY[?]::varchar[]", @filters.categories)
      end
      if @filters.keyword
        like = "%#{@filters.keyword.downcase}%"
        scope = scope.where("LOWER(handle) LIKE ? OR LOWER(display_name) LIKE ?", like, like)
      end
      scope
    end

    def apply_sort(scope)
      case @filters.sort
      when "followers_desc" then scope.order(follower_count: :desc)
      when "engagement_desc" then scope.order(engagement_rate: :desc)
      when "gmv_asc" then scope.order(gmv_cents: :asc)
      else scope.order(gmv_cents: :desc)
      end
    end

    # If the shop has a TikTok connection, hit the live API and upsert results
    # into the global Creator cache. Failures are logged and swallowed — search
    # always falls back to the cache.
    def sync_from_tiktok_if_connected
      return unless @shop.tiktok_connected?
      return unless Tiktok::RateLimiter.new(shop_id: @shop.id, bucket: :search).allow?

      token = @shop.tiktok_token
      result = Tiktok::Resources::AffiliateCreator.new(
        token: token,
        shop_cipher: token.shop_cipher
      ).search(filters: api_filters)

      result.creators.each { |c| upsert_creator(c) }
      Tiktok::RateLimiter.new(shop_id: @shop.id, bucket: :search).record!
    rescue Tiktok::Error => e
      Rails.logger.warn("[creator search] TikTok API error: #{e.class.name}: #{e.message}")
    end

    def api_filters
      {
        min_gmv_cents: @filters.min_gmv_cents,
        max_gmv_cents: @filters.max_gmv_cents,
        gmv_tier:      @filters.gmv_tier,
        min_followers: @filters.min_followers,
        max_followers: @filters.max_followers,
        categories:    @filters.categories,
        country:       @filters.country,
        keyword:       @filters.keyword,
        sort:          @filters.sort,
        page_size:     @filters.per_page
      }.compact
    end

    def upsert_creator(api_creator)
      Creator.upsert(
        {
          external_id:     api_creator.external_id,
          handle:          api_creator.handle,
          display_name:    api_creator.display_name,
          avatar_url:      api_creator.avatar_url,
          follower_count:  api_creator.follower_count,
          avg_views:       api_creator.avg_views,
          engagement_rate: api_creator.engagement_rate,
          gmv_cents:       api_creator.gmv_cents,
          gmv_tier:        api_creator.gmv_tier,
          country:         api_creator.country,
          categories:      api_creator.categories,
          last_seen_at:    Time.current,
          raw:             api_creator.raw,
          updated_at:      Time.current,
          created_at:      Time.current
        },
        unique_by: :external_id
      )
    end
  end
end
