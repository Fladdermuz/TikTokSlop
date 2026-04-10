namespace :db do
  namespace :seed do
    desc "Seed product knowledge for dev products (idempotent)"
    task product_knowledge: :environment do
      abort "refuse to run in production" if Rails.env.production?

      shop = Shop.find_by(slug: "tikedon-hq")
      abort "Tikedon HQ shop not found" unless shop
      Current.shop = shop

      knowledge_data = {
        "sku_vitc_30ml" => {
          short_description: "High-potency Vitamin C serum for brighter, firmer skin.",
          long_description: "A lightweight, fast-absorbing serum with 20% L-ascorbic acid, hyaluronic acid, and vitamin E. Targets dark spots, fine lines, and uneven skin tone. Suitable for all skin types.",
          ingredients: "Water, L-Ascorbic Acid (20%), Propylene Glycol, Hyaluronic Acid, Vitamin E (Tocopherol), Ferulic Acid, Citric Acid",
          benefits: "Brightens skin tone\nReduces appearance of dark spots\nBoosts collagen production\nAntioxidant protection against environmental stressors",
          target_audience: "Skincare-focused creators, beauty influencers, women 25-45 interested in anti-aging and skin brightening",
          use_cases: "Morning routine after cleanser and before moisturizer. Apply 3-5 drops to face and neck.",
          usp: "20% concentration with ferulic acid for enhanced stability — most competitors use 10-15%",
          brand_name: "Bionox",
          brand_voice: "Friendly, science-backed, not hyped. Emphasize ingredients and results, not miracles.",
          size_or_serving: "30ml / 1 fl oz",
          certifications: %w[cruelty-free vegan paraben-free],
          warnings: "For external use only. Avoid contact with eyes. Use sunscreen during the day."
        },
        "sku_collagen_250g" => {
          short_description: "Grass-fed collagen peptides powder for joints, skin, and gut health.",
          long_description: "Type I & III collagen peptides sourced from grass-fed, pasture-raised bovine. Dissolves easily in hot or cold beverages. 10g protein per serving. Unflavored.",
          ingredients: "Hydrolyzed Bovine Collagen Peptides (Type I & III)",
          benefits: "Supports joint flexibility\nImproves skin hydration and elasticity\nStrengthens hair and nails\nSupports gut lining health",
          target_audience: "Fitness creators, wellness influencers, women 30-55 interested in anti-aging, athletes focused on recovery",
          use_cases: "Mix one scoop into coffee, smoothies, oatmeal, or water. Morning or post-workout.",
          usp: "Single-ingredient, no fillers. Grass-fed sourcing verified. 25 servings per bag.",
          brand_name: "Bionox",
          brand_voice: "Clean, minimal, honest about ingredients. Emphasize sourcing quality.",
          size_or_serving: "250g bag, 25 servings",
          certifications: %w[grass-fed non-gmo gluten-free],
          warnings: "Contains bovine-derived ingredients. Not suitable for vegetarians/vegans."
        },
        "sku_ashwa_60" => {
          short_description: "KSM-66 Ashwagandha capsules for stress relief and focus.",
          long_description: "Full-spectrum KSM-66 ashwagandha root extract, 600mg per serving. Standardized to 5% withanolides. Third-party tested.",
          ingredients: "KSM-66 Ashwagandha Root Extract (Withania somnifera) 600mg, Vegetable Cellulose Capsule, Rice Flour",
          benefits: "Helps the body adapt to stress\nSupports calm focus and mental clarity\nMay support healthy cortisol levels\nSupports restful sleep when taken at night",
          target_audience: "Wellness creators, productivity/focus content, students, busy professionals, biohacking community",
          use_cases: "Take 1 capsule daily with food. Morning for focus, evening for sleep support.",
          usp: "KSM-66 is the most clinically studied ashwagandha extract. 5% withanolides standardization.",
          brand_name: "Bionox",
          brand_voice: "Science-first, reference studies when possible, never make cure claims.",
          size_or_serving: "60 capsules, 60 servings",
          certifications: %w[vegan non-gmo third-party-tested],
          warnings: "Consult healthcare provider if pregnant, nursing, or taking medications."
        }
      }

      created = 0
      knowledge_data.each do |sku, attrs|
        product = shop.products.find_by(external_id: sku)
        next unless product
        next if product.knowledge.present?
        product.create_knowledge!(attrs.merge(imported_at: Time.current))
        created += 1
      end

      puts "product_knowledge: created=#{created}, total=#{ProductKnowledge.count}"
    ensure
      Current.reset
    end
  end
end
