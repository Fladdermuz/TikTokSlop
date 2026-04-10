# Seed data — idempotent. Safe to run on any environment.
#
# Creates a platform admin user and one starting shop, both bootstrapped from
# environment variables so secrets aren't committed.
#
#   ADMIN_EMAIL=matt@tikedon.com ADMIN_PASSWORD=changeme bin/rails db:seed
#
# In dev, sane defaults are used if env vars are unset.

admin_email = ENV.fetch("ADMIN_EMAIL") {
  Rails.env.production? ? abort("ADMIN_EMAIL is required in production") : "matt@tikedon.com"
}

admin_password = ENV.fetch("ADMIN_PASSWORD") {
  Rails.env.production? ? abort("ADMIN_PASSWORD is required in production") : "password1234"
}

admin_name = ENV.fetch("ADMIN_NAME", "Matt")

shop_name = ENV.fetch("SHOP_NAME", "Tikedon HQ")

admin = User.find_or_initialize_by(email_address: admin_email)
admin.assign_attributes(
  name: admin_name,
  platform_admin: true,
  password: admin_password,
  password_confirmation: admin_password
) if admin.new_record?
admin.platform_admin = true
admin.name ||= admin_name
admin.save!
puts "platform admin: #{admin.email_address} (id=#{admin.id})"

shop = Shop.find_or_create_by!(slug: shop_name.parameterize) do |s|
  s.name = shop_name
  s.timezone = "Pacific Time (US & Canada)"
end
puts "shop: #{shop.name} (id=#{shop.id}, slug=#{shop.slug})"

membership = Membership.find_or_create_by!(user: admin, shop: shop) do |m|
  m.role = "owner"
  m.joined_at = Time.current
end
puts "membership: user=#{membership.user_id} shop=#{membership.shop_id} role=#{membership.role}"
