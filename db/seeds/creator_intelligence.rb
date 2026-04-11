# Seed realistic sample activity and recommended products onto existing creators.
# Run via: RAILS_ENV=production bin/rails runner db/seeds/creator_intelligence.rb
#
# The data is category-aware: beauty creators get skincare samples,
# fitness creators get supplement samples, etc.

BEAUTY_SAMPLE_REQUESTS = [
  { product_name: "Glow Recipe Watermelon Toner", seller_name: "K-Beauty Direct",     status: "received",  request_date: "Mar 12, 2026" },
  { product_name: "CeraVe Hydrating Facial Cleanser", seller_name: "Skincare Essentials", status: "approved",  request_date: "Mar 24, 2026" },
  { product_name: "The Ordinary Niacinamide 10%", seller_name: "Deciem Official Shop",   status: "received",  request_date: "Feb 28, 2026" },
  { product_name: "Paula's Choice BHA Exfoliant",  seller_name: "Paula's Choice",         status: "pending",   request_date: "Apr 1, 2026" },
  { product_name: "La Roche-Posay SPF 50+ Serum",  seller_name: "La Roche-Posay US",      status: "approved",  request_date: "Mar 18, 2026" },
  { product_name: "COSRX Snail Mucin Essence",     seller_name: "Seoul Glow Shop",         status: "received",  request_date: "Feb 14, 2026" },
  { product_name: "Tatcha Rice Polish Cleanser",   seller_name: "Tatcha Beauty",           status: "pending",   request_date: "Apr 3, 2026" },
  { product_name: "Drunk Elephant Protini Cream",  seller_name: "Drunk Elephant Official", status: "approved",  request_date: "Mar 5, 2026" },
].freeze

FITNESS_SAMPLE_REQUESTS = [
  { product_name: "Optimum Nutrition Gold Standard Whey", seller_name: "ON Official",         status: "received", request_date: "Mar 10, 2026" },
  { product_name: "Thorne Magnesium Bisglycinate",        seller_name: "Thorne Research",     status: "approved", request_date: "Mar 22, 2026" },
  { product_name: "Athletic Greens AG1 Starter Kit",      seller_name: "AG1 by Athletic Greens", status: "pending", request_date: "Apr 2, 2026" },
  { product_name: "Ghost Legend Pre-Workout",             seller_name: "Ghost Lifestyle",     status: "received", request_date: "Feb 19, 2026" },
  { product_name: "Momentous Essential Protein",          seller_name: "Momentous",           status: "approved", request_date: "Mar 15, 2026" },
  { product_name: "Nutrabolt C4 Sport Pre-Workout",       seller_name: "Cellucor Store",      status: "received", request_date: "Feb 27, 2026" },
  { product_name: "Vital Proteins Collagen Peptides",     seller_name: "Vital Proteins",      status: "pending",  request_date: "Apr 5, 2026" },
  { product_name: "Ancient Nutrition Multi Collagen",     seller_name: "Ancient Nutrition",   status: "approved", request_date: "Mar 8, 2026" },
].freeze

FOOD_SAMPLE_REQUESTS = [
  { product_name: "Magic Spoon Grain-Free Cereal",   seller_name: "Magic Spoon",       status: "received", request_date: "Mar 11, 2026" },
  { product_name: "Chomps Beef Jerky Sticks",        seller_name: "Chomps Snacks",     status: "approved", request_date: "Mar 26, 2026" },
  { product_name: "Hu Kitchen Dark Chocolate",       seller_name: "Hu Kitchen",        status: "received", request_date: "Feb 22, 2026" },
  { product_name: "Siete Grain-Free Tortillas",      seller_name: "Siete Foods",       status: "pending",  request_date: "Apr 4, 2026" },
  { product_name: "Purely Elizabeth Granola",        seller_name: "Purely Elizabeth",  status: "received", request_date: "Mar 3, 2026" },
  { product_name: "RXBar Chocolate Sea Salt",        seller_name: "RXBAR Official",    status: "approved", request_date: "Mar 19, 2026" },
].freeze

FASHION_SAMPLE_REQUESTS = [
  { product_name: "Skims Cotton Rib Tank Set",       seller_name: "Skims Official",    status: "received", request_date: "Mar 14, 2026" },
  { product_name: "Lululemon Align Leggings",        seller_name: "Lululemon TT Shop", status: "approved", request_date: "Mar 28, 2026" },
  { product_name: "Free People Movement Set",        seller_name: "Free People",       status: "pending",  request_date: "Apr 1, 2026" },
  { product_name: "Vuori Performance Shorts",        seller_name: "Vuori Clothing",    status: "received", request_date: "Feb 17, 2026" },
  { product_name: "Alo Yoga High-Waist Legging",     seller_name: "Alo Yoga Official", status: "approved", request_date: "Mar 7, 2026" },
].freeze

LIFESTYLE_SAMPLE_REQUESTS = [
  { product_name: "Hatch Restore 2 Alarm Clock",   seller_name: "Hatch Sleep",         status: "received", request_date: "Mar 9, 2026" },
  { product_name: "Therabody Theragun Mini",        seller_name: "Therabody Official",  status: "approved", request_date: "Mar 20, 2026" },
  { product_name: "Oura Ring Gen 3",               seller_name: "Oura Health",         status: "pending",  request_date: "Apr 2, 2026" },
  { product_name: "Caraway Cookware Set",          seller_name: "Caraway Home",        status: "received", request_date: "Feb 25, 2026" },
  { product_name: "Our Place Always Pan",          seller_name: "Our Place",           status: "approved", request_date: "Mar 16, 2026" },
].freeze

# Recommended products data — keyed by category theme
BEAUTY_RECOMMENDED = [
  { product_name: "Vitamin C Brightening Serum 20%",         match_score: 0.94, reason: "Audience skews 18-34F with active skincare interest" },
  { product_name: "Hyaluronic Acid Plumping Moisturizer",    match_score: 0.88, reason: "Strong fit with hydration-focused content style" },
  { product_name: "Retinol Night Repair Cream",              match_score: 0.82, reason: "Consistent engagement on anti-aging posts" },
  { product_name: "Gentle Foaming Cleanser SPF 30",          match_score: 0.71, reason: "Complements existing morning routine content" },
  { product_name: "Rose Water Facial Mist",                  match_score: 0.63, reason: "High save rate on hydration & glow content" },
].freeze

FITNESS_RECOMMENDED = [
  { product_name: "Whey Isolate Performance Blend",          match_score: 0.96, reason: "Audience is 25-40M with high post-workout supplement intent" },
  { product_name: "Creatine Monohydrate Pure",               match_score: 0.89, reason: "Frequent strength training content aligns well" },
  { product_name: "Electrolyte Recovery Drink Mix",          match_score: 0.84, reason: "Endurance content drives strong conversion signals" },
  { product_name: "Ashwagandha Stress & Recovery Capsules",  match_score: 0.73, reason: "Recovery content resonates strongly with their followers" },
  { product_name: "Fish Oil Omega-3 2000mg",                 match_score: 0.65, reason: "Health & wellness category overlap" },
].freeze

FOOD_RECOMMENDED = [
  { product_name: "High-Protein Overnight Oats Mix",         match_score: 0.91, reason: "Meal-prep content format matches perfectly" },
  { product_name: "Low-Sugar Protein Granola Clusters",      match_score: 0.86, reason: "Snack haul content drives high save rates" },
  { product_name: "Organic Matcha Ceremonial Grade",         match_score: 0.79, reason: "Morning routine content is consistently high-performing" },
  { product_name: "Clean Greens Superfood Powder",           match_score: 0.68, reason: "Wellness smoothie content trend alignment" },
].freeze

FASHION_RECOMMENDED = [
  { product_name: "Seamless Sculpt Set (Bra + Shorts)",      match_score: 0.93, reason: "GRWM and outfit-of-the-day content performs at 8.2% ER" },
  { product_name: "Oversized Cotton Crewneck Sweatshirt",    match_score: 0.85, reason: "Casual lifestyle content has strong audience resonance" },
  { product_name: "High-Rise Wide-Leg Trousers",             match_score: 0.78, reason: "Trending silhouette aligned with creator's aesthetic" },
  { product_name: "Ribbed Longline Tank",                    match_score: 0.66, reason: "Wardrobe staples content drives repeat views" },
].freeze

LIFESTYLE_RECOMMENDED = [
  { product_name: "Bamboo Desk Organizer Set",               match_score: 0.87, reason: "Home office & aesthetic desk setup content thrives" },
  { product_name: "Premium Candle Gift Set",                 match_score: 0.82, reason: "Lifestyle unboxing content averages 450K views" },
  { product_name: "Weighted Blanket 15lb",                   match_score: 0.76, reason: "Sleep & cozy content segment growing fast" },
  { product_name: "Minimalist Desk Lamp",                    match_score: 0.69, reason: "Room tour and decor content is evergreen performer" },
].freeze

def category_pool(categories)
  cats = Array(categories).map(&:downcase)
  if    cats.any? { |c| c.include?("beauty") || c.include?("skin") || c.include?("makeup") }
    [:beauty]
  elsif cats.any? { |c| c.include?("fitness") || c.include?("sport") || c.include?("health") || c.include?("gym") }
    [:fitness]
  elsif cats.any? { |c| c.include?("food") || c.include?("cook") || c.include?("nutrition") }
    [:food]
  elsif cats.any? { |c| c.include?("fashion") || c.include?("style") || c.include?("clothing") }
    [:fashion]
  else
    [:lifestyle]
  end
end

def sample_pool_for(pool_key)
  case pool_key
  when :beauty   then BEAUTY_SAMPLE_REQUESTS
  when :fitness  then FITNESS_SAMPLE_REQUESTS
  when :food     then FOOD_SAMPLE_REQUESTS
  when :fashion  then FASHION_SAMPLE_REQUESTS
  else                LIFESTYLE_SAMPLE_REQUESTS
  end
end

def rec_pool_for(pool_key)
  case pool_key
  when :beauty   then BEAUTY_RECOMMENDED
  when :fitness  then FITNESS_RECOMMENDED
  when :food     then FOOD_RECOMMENDED
  when :fashion  then FASHION_RECOMMENDED
  else                LIFESTYLE_RECOMMENDED
  end
end

updated = 0
Creator.find_each do |creator|
  pool_key = category_pool(creator.categories).first

  # Pick 3-4 sample requests
  samples = sample_pool_for(pool_key).sample(rand(3..4))

  # Pick top 3-5 recommended products (already sorted by score in pool)
  recs = rec_pool_for(pool_key).first(rand(3..5))

  creator.update_columns(
    recent_sample_requests: samples,
    recommended_products:   recs
  )
  updated += 1
end

puts "Seeded sample intelligence onto #{updated} creators."
