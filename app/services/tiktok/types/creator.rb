module Tiktok
  module Types
    # A creator returned from the affiliate creator search endpoint.
    # Field names are normalized — TikTok's response shapes vary across versions
    # so we map at this layer and keep the rest under :raw.
    Creator = Data.define(
      :external_id,
      :handle,
      :display_name,
      :avatar_url,
      :follower_count,
      :avg_views,
      :engagement_rate,
      :gmv_cents,
      :gmv_tier,
      :country,
      :categories,
      :raw
    ) do
      def self.from_api(hash)
        new(
          external_id:     (hash["creator_id"] || hash["id"]).to_s,
          handle:          hash["handle"] || hash["username"],
          display_name:    hash["display_name"] || hash["nickname"],
          avatar_url:      hash["avatar_url"] || hash.dig("avatar", "url"),
          follower_count:  hash["follower_count"].to_i,
          avg_views:       hash["avg_video_views"].to_i,
          engagement_rate: hash["engagement_rate"]&.to_f,
          gmv_cents:       gmv_to_cents(hash["gmv_30d"] || hash["gmv"]),
          gmv_tier:        hash["gmv_tier"],
          country:         hash["country_code"] || hash["region"],
          categories:      Array(hash["categories"] || hash["category_names"]),
          raw:             hash
        )
      end

      def self.gmv_to_cents(value)
        return 0 if value.nil?
        # TikTok returns GMV in dollars; we store cents
        (value.to_f * 100).round
      end
    end
  end
end
