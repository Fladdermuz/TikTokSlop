# Pull shop video performance data from TikTok and upsert into creator_videos.
# Each video is linked to its Creator record by external creator_id (if we know
# that creator), and to a Campaign/Invite/Product by matching the product_id
# against our campaigns.
#
# Scope: data.shop_analytics.public.read
#   Endpoints used:
#     - Get Shop Video Performance List (paginated)
#     - Get Shop Video Performance Details (per-video lookup for enrichment)
class Tiktok::SyncShopVideosJob < ApplicationJob
  queue_as :tiktok
  discard_on ActiveRecord::RecordNotFound
  retry_on Tiktok::RateLimitError, wait: :polynomially_longer, attempts: 3

  PAGE_SIZE = 50
  LOOKBACK_DAYS = 30

  METRICS = %w[views likes comments shares orders gmv].freeze

  def perform(shop_id, start_date: nil, end_date: nil)
    shop = Shop.find(shop_id)
    token = TiktokToken.cross_tenant.find_by(shop: shop)
    return unless token

    start_date ||= LOOKBACK_DAYS.days.ago.to_date.iso8601
    end_date   ||= Date.current.iso8601

    analytics = Tiktok::Resources::Analytics.new(token: token, shop_cipher: token.shop_cipher)
    page_token = nil
    total_upserted = 0

    loop do
      body = analytics.video_performance_list(
        start_date: start_date, end_date: end_date,
        metrics: METRICS, page_size: PAGE_SIZE, page_token: page_token
      )
      videos = Array(body.dig("data", "videos"))
      break if videos.empty?

      videos.each do |v|
        upsert_video(shop, v)
        total_upserted += 1
      end

      page_token = body.dig("data", "next_page_token")
      break if page_token.blank?
    end

    Rails.logger.info("[sync_shop_videos] shop=#{shop.id} upserted=#{total_upserted}")
  rescue Tiktok::Error => e
    Rails.logger.warn("[sync_shop_videos] shop=#{shop_id}: #{e.class.name}: #{e.message}")
  end

  private

  def upsert_video(shop, v)
    external_id = v["video_id"] || v["id"]
    return if external_id.blank?

    creator_external = v["creator_id"] || v.dig("creator", "id")
    product_external = v["product_id"] || v.dig("product", "id")

    creator = shop_creator_for(creator_external)
    product = shop.products.find_by(external_id: product_external) if product_external.present?
    invite  = find_invite(creator, product) if creator && product
    campaign = invite&.campaign || find_campaign(shop, product)

    video = CreatorVideo.cross_tenant.find_or_initialize_by(external_id: external_id)
    video.assign_attributes(
      shop: shop,
      creator: creator,
      product: product,
      campaign: campaign,
      invite: invite,
      title:        v["title"] || v["description"],
      thumbnail_url: v["cover_url"] || v["thumbnail_url"],
      video_url:    v["share_url"] || v["video_url"],
      posted_at:    parse_time(v["create_time"] || v["posted_at"]),
      views:        v.dig("metrics", "views").to_i,
      likes:        v.dig("metrics", "likes").to_i,
      comments:     v.dig("metrics", "comments").to_i,
      shares:       v.dig("metrics", "shares").to_i,
      attributed_orders:    v.dig("metrics", "orders").to_i,
      attributed_gmv_cents: ((v.dig("metrics", "gmv") || 0).to_f * 100).to_i,
      currency:     v["currency"] || "USD",
      raw:          v
    )
    video.save!
  end

  def shop_creator_for(external_id)
    return nil if external_id.blank?
    Creator.find_by(external_id: external_id)
  end

  def find_invite(creator, product)
    Invite.cross_tenant
          .joins(:campaign)
          .where(creator_id: creator.id, campaigns: { product_id: product.id })
          .order(created_at: :desc)
          .first
  end

  def find_campaign(shop, product)
    return nil unless product
    shop.campaigns.where(product_id: product.id).order(created_at: :desc).first
  end

  def parse_time(value)
    return nil if value.blank?
    value.is_a?(Integer) ? Time.at(value) : Time.parse(value.to_s)
  rescue ArgumentError
    nil
  end
end
