# AI-powered outreach message generation using Claude.
#
# Two modes:
#   - template: one call per campaign, generates a reusable template with {{variables}}
#   - personalized: one call per creator, references their specific niche/content
#
# Every generated message is automatically piped through `Moderation::Scanner`.
# If moderation flags it, the crafter retries up to MAX_RETRIES times with
# feedback about which phrases to avoid.
module Messaging
  class Crafter
    MAX_RETRIES = 2

    TEMPLATE_SYSTEM = <<~PROMPT.freeze
      You are a TikTok Shop affiliate outreach specialist. Write a message from a
      seller to a creator inviting them to promote a product as an affiliate.

      Rules:
      1. Be friendly, professional, and BRIEF (150–300 characters ideally, max 500).
      2. Reference the SPECIFIC product and its real benefits — not generic fluff.
      3. Include template variables where creator info should go: {{creator.handle}},
         {{creator.display_name}}, {{creator.top_category}}.
      4. Also available: {{shop.name}}, {{product.name}}, {{campaign.name}},
         {{campaign.commission_pct}}.
      5. Do NOT use any income guarantees, medical claims, urgency phrases, competitor
         names, or references to off-platform messaging (WhatsApp, Instagram, etc.).
      6. Sound like a real person, not a bot. No ALL CAPS. No "limited time offer".
      7. Return ONLY the message text — no commentary, no quotes, no "Subject:" prefix.
    PROMPT

    PERSONALIZED_SYSTEM = <<~PROMPT.freeze
      You are a TikTok Shop affiliate outreach specialist. Write a personalized
      message from a seller to a SPECIFIC creator inviting them to promote a product.

      Rules:
      1. Be friendly, professional, and BRIEF (200–400 characters, max 500).
      2. Reference the specific product and its real benefits.
      3. Reference something about the creator's profile: their niche, follower size,
         or content style — make it feel like the seller actually looked at their work.
      4. Do NOT use template variables like {{creator.handle}} — use the creator's
         actual name/handle directly.
      5. Do NOT use income guarantees, medical claims, urgency phrases, competitor
         names, or references to off-platform messaging.
      6. Sound like a real person. No ALL CAPS. No "limited time offer".
      7. Return ONLY the message text — no commentary, no quotes.
    PROMPT

    CraftResult = Data.define(:text, :moderation_result, :model, :retries_used, :cached)

    class << self
      # Generate a reusable template with {{variables}} for a campaign.
      def template_for(campaign:, shop:)
        product = campaign.product
        pk = product.knowledge

        cache_key = template_cache_key(campaign, pk)
        cached = Rails.cache.read(cache_key)
        return cached if cached.is_a?(CraftResult)

        user_prompt = build_template_prompt(campaign, product, pk, shop)
        result = generate_with_moderation(
          system: TEMPLATE_SYSTEM,
          user: user_prompt,
          shop: shop,
          feature: "crafter_template",
          model: :sonnet
        )

        result = CraftResult.new(**result.to_h.merge(cached: false))
        Rails.cache.write(cache_key, result, expires_in: 7.days) if result.moderation_result.passable?
        result
      end

      # Generate a personalized message for a specific creator.
      def personalized_for(campaign:, creator:, shop:)
        product = campaign.product
        pk = product.knowledge

        cache_key = personalized_cache_key(campaign, creator, pk)
        cached = Rails.cache.read(cache_key)
        return cached if cached.is_a?(CraftResult)

        user_prompt = build_personalized_prompt(campaign, product, pk, shop, creator)
        result = generate_with_moderation(
          system: PERSONALIZED_SYSTEM,
          user: user_prompt,
          shop: shop,
          feature: "crafter_personalized",
          model: :sonnet
        )

        result = CraftResult.new(**result.to_h.merge(cached: false))
        Rails.cache.write(cache_key, result, expires_in: 24.hours) if result.moderation_result.passable?
        result
      end

      private

      def generate_with_moderation(system:, user:, shop:, feature:, model:)
        client = Ai::Client.new(shop: shop, feature: feature)
        retries = 0
        last_moderation = nil

        loop do
          prompt = retries.zero? ? user : add_retry_feedback(user, last_moderation)
          response = client.complete(system: system, user: prompt, model: model, max_tokens: 600, temperature: 0.7)
          text = response.text.strip

          moderation = Moderation::Scanner.scan(text, shop: shop, use_ai: retries < MAX_RETRIES)

          if moderation.passable? || retries >= MAX_RETRIES
            return CraftResult.new(
              text: text,
              moderation_result: moderation,
              model: response.model,
              retries_used: retries,
              cached: false
            )
          end

          last_moderation = moderation
          retries += 1
        end
      end

      def add_retry_feedback(original_prompt, moderation)
        flagged = moderation.issues.map { |i| i[:phrase] }.compact.uniq.join(", ")
        "#{original_prompt}\n\nIMPORTANT: Your previous draft was flagged. AVOID these phrases: #{flagged}. Rewrite to bypass TikTok's content filter while keeping the same intent."
      end

      def build_template_prompt(campaign, product, pk, shop)
        parts = []
        parts << "Shop: #{shop.name}"
        parts << "Campaign: #{campaign.name}"
        parts << "Commission: #{campaign.commission_rate ? "#{(campaign.commission_rate * 100).round(1)}%" : 'negotiable'}"
        parts << "Sample offer: #{campaign.sample_offer? ? 'yes, free product sample included' : 'no'}"
        parts << ""
        if pk&.populated?
          parts << "Product knowledge:"
          parts << pk.to_prompt_context
        else
          parts << "Product: #{product.name}"
          parts << "Price: $#{product.price_dollars}" if product.price_cents > 0
        end
        parts << ""
        parts << "Write the outreach template with {{variable}} placeholders for the creator's info."
        parts.join("\n")
      end

      def build_personalized_prompt(campaign, product, pk, shop, creator)
        parts = []
        parts << "Shop: #{shop.name}"
        parts << "Campaign: #{campaign.name}"
        parts << "Commission: #{campaign.commission_rate ? "#{(campaign.commission_rate * 100).round(1)}%" : 'negotiable'}"
        parts << "Sample: #{campaign.sample_offer? ? 'yes' : 'no'}"
        parts << ""
        if pk&.populated?
          parts << "Product knowledge:"
          parts << pk.to_prompt_context
        else
          parts << "Product: #{product.name}"
        end
        parts << ""
        parts << "Creator profile:"
        parts << "  Handle: @#{creator.handle}"
        parts << "  Display name: #{creator.display_name}" if creator.display_name.present?
        parts << "  Followers: #{creator.follower_count}"
        parts << "  Top category: #{Array(creator.categories).first}" if creator.categories.present?
        parts << "  Country: #{creator.country}" if creator.country.present?
        parts << ""
        parts << "Write a personalized message directly to this creator. Use their actual name/handle."
        parts.join("\n")
      end

      def template_cache_key(campaign, pk)
        seed = "#{campaign.id}:#{campaign.commission_rate}:#{campaign.sample_offer}:#{pk&.updated_at&.to_i}"
        "crafter:template:#{Digest::SHA256.hexdigest(seed)}"
      end

      def personalized_cache_key(campaign, creator, pk)
        seed = "#{campaign.id}:#{creator.id}:#{pk&.updated_at&.to_i}"
        "crafter:personalized:#{Digest::SHA256.hexdigest(seed)}"
      end
    end
  end
end
