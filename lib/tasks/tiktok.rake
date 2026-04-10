namespace :tiktok do
  desc "Smoke test the TikTok client end-to-end against a real shop's saved token"
  task ping: :environment do
    token = TiktokToken.cross_tenant.order(updated_at: :desc).first
    if token.nil?
      abort "no TiktokToken on file. Connect a shop first via /shop/tiktok_connection."
    end

    puts "Using token for shop_id=#{token.shop_id} (external_shop_id=#{token.external_shop_id})"
    puts "Access expires at: #{token.access_expires_at}"
    puts

    if token.access_expired?
      puts "Access token is expired. Refreshing..."
      pair = Tiktok::Resources::Authorization.refresh(token.refresh_token)
      token.update!(
        access_token:       pair.access_token,
        refresh_token:      pair.refresh_token,
        access_expires_at:  pair.access_expires_at,
        refresh_expires_at: pair.refresh_expires_at
      )
      puts "Refreshed."
    end

    puts "Calling Tiktok::Resources::Shop#list..."
    shops = Tiktok::Resources::Shop.new(token: token).list
    puts JSON.pretty_generate(shops)
  rescue Tiktok::Error => e
    abort "TikTok error: #{e.class.name.split('::').last} code=#{e.code} status=#{e.http_status} request_id=#{e.request_id} message=#{e.message}"
  end

  desc "Print the canonical signing string for given args (debugging)"
  task :sign_debug, [ :path ] => :environment do |_, args|
    path = args[:path] || "/api/orders/202309/list"
    query = { app_key: "demo_key", timestamp: Time.now.to_i.to_s, version: "202309" }
    canonical = Tiktok::Signer.canonical_string(query)
    full = path + canonical
    sig = Tiktok::Signer.sign(method: :get, path: path, query: query, app_secret: "demo_secret")
    puts "path:      #{path}"
    puts "query:     #{query.inspect}"
    puts "canonical: #{canonical}"
    puts "to_sign:   #{full}"
    puts "wrapped:   demo_secret#{full}demo_secret"
    puts "sign:      #{sig}"
  end
end
