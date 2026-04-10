namespace :db do
  namespace :seed do
    desc "Seed fake products for the default dev shop (idempotent)"
    task products: :environment do
      abort "refuse to run in production" if Rails.env.production?

      shop = Shop.find_by(slug: "tikedon-hq")
      unless shop
        abort "Tikedon HQ shop not found — run `bin/rails db:seed` first"
      end

      Current.shop = shop

      products = [
        { name: "Vitamin C Serum",     price_cents: 2499,  external_id: "sku_vitc_30ml" },
        { name: "Collagen Peptides",    price_cents: 3999,  external_id: "sku_collagen_250g" },
        { name: "Ashwagandha Capsules", price_cents: 1899,  external_id: "sku_ashwa_60" },
        { name: "Magnesium Glycinate",  price_cents: 2299,  external_id: "sku_mag_gly_120" },
        { name: "Electrolyte Mix",      price_cents: 2999,  external_id: "sku_lyte_30pk" },
        { name: "Protein Bar (12-pack)", price_cents: 2499, external_id: "sku_bar_choc_12" }
      ]

      created = 0
      products.each do |attrs|
        next if shop.products.find_by(external_id: attrs[:external_id])
        shop.products.create!(attrs.merge(currency: "USD", status: "active"))
        created += 1
      end

      puts "products: created=#{created}, total=#{shop.products.count}"
    ensure
      Current.reset
    end
  end
end
