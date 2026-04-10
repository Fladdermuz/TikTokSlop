module Tiktok
  module Types
    # Returned by the token exchange and refresh endpoints.
    TokenPair = Data.define(
      :access_token,
      :refresh_token,
      :access_expires_at,
      :refresh_expires_at,
      :seller_name,
      :open_id,
      :raw
    ) do
      def self.from_api(hash)
        data = hash["data"] || hash
        new(
          access_token:       data["access_token"],
          refresh_token:      data["refresh_token"],
          access_expires_at:  Time.at(data["access_token_expire_in"].to_i),
          refresh_expires_at: Time.at(data["refresh_token_expire_in"].to_i),
          seller_name:        data["seller_name"],
          open_id:            data["open_id"],
          raw:                data
        )
      end
    end
  end
end
