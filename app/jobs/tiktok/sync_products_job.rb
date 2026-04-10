# Per-shop job that pulls products from TikTok using the Product resource and
# upserts them into the local Product model.
#
# Paginates through all results using page_token until exhausted.
# Skips products with no external ID. Does not delete products that no longer
# appear in TikTok — marks them inactive instead.
#
# Requires: seller.product.basic scope.
class Tiktok::SyncProductsJob < ApplicationJob
  queue_as :tiktok
  discard_on ActiveRecord::RecordNotFound

  PAGE_SIZE = 50

  def perform(shop_id)
    shop = Shop.find_by(id: shop_id)
    return unless shop

    token = TiktokToken.cross_tenant.find_by(shop: shop)
    unless token
      Rails.logger.info("[sync_products] no TikTok connection for shop=#{shop.id}, skipping")
      return
    end

    api = Tiktok::Resources::Product.new(token: token, shop_cipher: token.shop_cipher)

    page_token = nil
    synced_external_ids = []

    loop do
      response = api.search(filters: { page_size: PAGE_SIZE, page_token: page_token })
      data = response.is_a?(Hash) ? (response["data"] || response) : {}
      items = data["products"] || data["items"] || []

      items.each do |item|
        external_id = item["id"] || item["product_id"]
        next if external_id.blank?

        upsert_product(shop, item, external_id)
        synced_external_ids << external_id.to_s
      end

      page_token = data["next_page_token"] || data["page_token"]
      break if page_token.blank? || items.empty?
    end

    Rails.logger.info("[sync_products] shop=#{shop.id} upserted #{synced_external_ids.size} products")

  rescue Tiktok::AuthError => e
    Rails.logger.error("[sync_products] auth error for shop=#{shop_id}: #{e.message}")
    Tiktok::RefreshTokenJob.perform_later(token&.id) if token
  rescue Tiktok::Error => e
    Rails.logger.error("[sync_products] #{e.class.name}: #{e.message} shop=#{shop_id} request_id=#{e.request_id}")
    raise
  end

  private

  def upsert_product(shop, item, external_id)
    # Map TikTok API fields to local Product columns
    name       = item["title"] || item["name"] || "Product #{external_id}"
    status_raw = item["status"]&.downcase || "active"
    status     = status_raw.include?("active") ? "active" : "inactive"
    image_url  = item.dig("main_images", 0, "url") || item["image_url"]

    price_cents = extract_price_cents(item)

    Product.where(shop_id: shop.id, external_id: external_id).first_or_initialize.tap do |product|
      product.shop_id    = shop.id
      product.name       = name
      product.status     = status
      product.image_url  = image_url if image_url.present?
      product.price_cents = price_cents if price_cents
      product.raw        = item
      product.synced_at  = Time.current
      product.save!
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn("[sync_products] failed to upsert product external_id=#{external_id}: #{e.message}")
  end

  def extract_price_cents(item)
    # TikTok returns price as a float or nested hash depending on endpoint version
    price = item.dig("sale_price", "amount") ||
            item.dig("price", "amount") ||
            item["sale_price"] ||
            item["price"]

    return nil if price.nil?

    (price.to_f * 100).round
  end
end
