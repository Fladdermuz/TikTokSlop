# Pull affiliate orders (commission-eligible sales attributed to creators) from
# TikTok and upsert into affiliate_orders. Each order gets linked to the
# Creator + Invite + Campaign locally when a match exists.
#
# Scope: seller.affiliate_collaboration.read
#   Endpoint used: Search Seller Affiliate Orders
class Tiktok::SyncAffiliateOrdersJob < ApplicationJob
  queue_as :tiktok
  discard_on ActiveRecord::RecordNotFound
  retry_on Tiktok::RateLimitError, wait: :polynomially_longer, attempts: 3

  PAGE_SIZE = 50
  LOOKBACK_DAYS = 30

  def perform(shop_id, start_time: nil, end_time: nil)
    shop = Shop.find(shop_id)
    token = TiktokToken.cross_tenant.find_by(shop: shop)
    return unless token

    start_time ||= LOOKBACK_DAYS.days.ago.to_i
    end_time   ||= Time.current.to_i

    collab = Tiktok::Resources::AffiliateCollaboration.new(token: token, shop_cipher: token.shop_cipher)
    page_token = nil
    total = 0

    loop do
      body = collab.search_affiliate_orders(filters: {
        start_time: start_time,
        end_time:   end_time,
        page_size:  PAGE_SIZE,
        page_token: page_token
      }.compact)

      orders = Array(body.dig("data", "orders"))
      break if orders.empty?

      orders.each do |o|
        upsert_order(shop, o)
        total += 1
      end

      page_token = body.dig("data", "next_page_token")
      break if page_token.blank?
    end

    Rails.logger.info("[sync_affiliate_orders] shop=#{shop.id} upserted=#{total}")
  rescue Tiktok::Error => e
    Rails.logger.warn("[sync_affiliate_orders] shop=#{shop_id}: #{e.class.name}: #{e.message}")
  end

  private

  def upsert_order(shop, o)
    external_id = o["order_id"] || o["id"]
    return if external_id.blank?

    creator_external = o["creator_id"] || o.dig("creator", "id")
    product_external = o["product_id"] || o.dig("product", "id")

    creator  = creator_external.present? ? Creator.find_by(external_id: creator_external) : nil
    product  = product_external.present? ? shop.products.find_by(external_id: product_external) : nil
    invite   = find_invite(creator, product)
    campaign = invite&.campaign || find_campaign(shop, product)

    record = AffiliateOrder.cross_tenant.find_or_initialize_by(external_id: external_id)
    record.assign_attributes(
      shop: shop,
      creator: creator,
      invite: invite,
      campaign: campaign,
      product: product,
      order_status:     (o["order_status"] || o["status"] || "pending").to_s.downcase,
      gmv_cents:        to_cents(o["gmv"] || o["total"] || o.dig("amount", "total")),
      commission_cents: to_cents(o["commission"] || o.dig("amount", "commission")),
      currency:         o["currency"] || "USD",
      ordered_at:       parse_time(o["ordered_at"] || o["create_time"]),
      raw:              o
    )
    record.save!
  end

  def to_cents(value)
    return 0 if value.blank?
    (value.to_f * 100).round
  end

  def find_invite(creator, product)
    return nil unless creator && product
    Invite.cross_tenant.joins(:campaign)
      .where(creator_id: creator.id, campaigns: { product_id: product.id })
      .order(created_at: :desc).first
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
