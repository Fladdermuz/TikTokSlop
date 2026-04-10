# Polls TikTok for sample status updates per shop. When a sample transitions to
# "delivered", auto-schedules the first Spark Code follow-up.
class Tiktok::SyncSampleStatusJob < ApplicationJob
  queue_as :tiktok

  def perform(shop_id)
    shop = Shop.find_by(id: shop_id)
    return unless shop

    token = TiktokToken.cross_tenant.find_by(shop: shop)
    return unless token

    open_samples = Sample.for_shop(shop).where(status: %w[requested approved shipped])
    return if open_samples.empty?

    api = Tiktok::Resources::AffiliateSample.new(token: token, shop_cipher: token.shop_cipher)

    # Use the search endpoint to fetch all open sample applications at once,
    # then match by external_id. This is more efficient than per-sample lookups
    # and matches the real TikTok API (search-based, not find-by-ID).
    remote_samples = fetch_remote_samples(api, open_samples)

    open_samples.find_each do |sample|
      sync_one(sample, remote_samples[sample.external_id])
    rescue Tiktok::Error => e
      Rails.logger.warn("[sync sample] error for sample=#{sample.id}: #{e.message}")
    end
  end

  private

  def fetch_remote_samples(api, open_samples)
    # Search sample applications via the real API and index by ID
    result = {}
    page_token = nil

    loop do
      response = api.search(filters: { page_size: 50, page_token: page_token })
      applications = Array(response.dig("data", "sample_applications"))
      applications.each do |app|
        id = app["sample_application_id"] || app["id"]
        result[id.to_s] = app if id
      end

      page_token = response.dig("data", "next_page_token")
      break if page_token.blank? || applications.empty?
    end

    result
  rescue Tiktok::Error => e
    Rails.logger.warn("[sync sample] error fetching remote samples: #{e.message}")
    {}
  end

  def sync_one(sample, data)
    return if sample.external_id.blank?
    return if data.nil?

    remote_status = data["status"]&.downcase
    return if remote_status.blank?

    new_status = map_status(remote_status)
    return if new_status == sample.status

    attrs = { status: new_status }
    attrs[:shipped_at] = Time.current if new_status == "shipped" && sample.shipped_at.nil?
    attrs[:delivered_at] = Time.current if new_status == "delivered" && sample.delivered_at.nil?
    attrs[:tracking_number] = data["tracking_number"] if data["tracking_number"].present?
    attrs[:carrier] = data["carrier"] if data["carrier"].present?

    sample.update!(attrs)

    # Auto-schedule Spark Code follow-up on delivery
    sample.on_delivery! if new_status == "delivered"

    Rails.logger.info("[sync sample] sample=#{sample.id} → #{new_status}")
  end

  def map_status(remote)
    case remote
    when "approved"  then "approved"
    when "rejected"  then "rejected"
    when "shipped"   then "shipped"
    when "delivered" then "delivered"
    when "returned"  then "returned"
    else remote
    end
  end
end
