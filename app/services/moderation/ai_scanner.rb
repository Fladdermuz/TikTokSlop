# Layer 2 moderation: Claude Haiku reads the message and flags anything the
# keyword scanner missed — phrasing, implied claims, disguised off-platform
# redirects, euphemisms, etc.
#
# Always called AFTER the keyword scanner short-circuits on hard blocks, so
# this only runs on messages we're not already sure are bad. Results cached
# by message hash for 24h so re-scanning a template is free.
module Moderation
  class AiScanner
    VERSION = 1
    CACHE_TTL = 24.hours

    SYSTEM_PROMPT = <<~PROMPT.freeze
      You are a TikTok Shop content moderation assistant. Your job is to review
      outreach messages that a seller plans to send to affiliate creators on
      TikTok Shop, and flag any phrases or claims TikTok is likely to reject.

      TikTok Shop is strict about:
      - Income, earnings, or financial claims (even implied)
      - Medical / health / weight-loss claims without FDA clearance
      - Redirecting creators off-platform (mentioning WhatsApp, Instagram DMs,
        email, phone numbers, external links, "DM me on...")
      - Urgent/high-pressure language ("act now", "limited time")
      - Competing e-commerce platforms (Amazon, Shopify, etc.)
      - Political or religious content
      - Trademarks without authorization
      - Personal contact information exchange
      - Sexual, drug, weapon, gambling, or crypto content

      You must return ONLY valid JSON in this exact shape, no prose, no
      markdown, no code fences:

      {
        "risk": "low" | "medium" | "high" | "blocked",
        "issues": [
          {
            "phrase": "<the problematic snippet>",
            "category": "<one of: income_claims, health_claims, external_platforms, contact_info, spam_markers, politics, competitor_platforms, restricted_products, other>",
            "severity": "low" | "medium" | "high",
            "reason": "<short explanation of why TikTok would flag this>"
          }
        ],
        "suggested_rewrite": "<optional: a rewritten version that avoids all issues, or null>"
      }

      Guidance:
      - "low" = no material issues, safe to send
      - "medium" = minor concerns, will probably send but might underperform
      - "high" = clear problems, will likely be rejected
      - "blocked" = will definitely be rejected — do not send as-is

      Only flag REAL issues. Do not over-flag normal friendly outreach.
      A message like "Hey! Love your skincare content — we'd love to send
      you our new serum for a review" is LOW risk, not medium.
    PROMPT

    def self.scan(text, shop:)
      return Moderation::Result.empty if text.blank?

      cached = Rails.cache.read(cache_key(text))
      return cached if cached.is_a?(Moderation::Result)

      client = Ai::Client.new(shop: shop, feature: "moderation")
      response = client.complete(
        system: SYSTEM_PROMPT,
        user: "Message to scan:\n\n#{text}",
        model: :haiku,
        max_tokens: 800,
        temperature: 0.1
      )

      result = build_result(response)
      Rails.cache.write(cache_key(text), result, expires_in: CACHE_TTL)
      result
    rescue Ai::Client::Error => e
      Rails.logger.warn("[moderation ai] #{e.class.name}: #{e.message} — falling back to empty result")
      # On AI failure, don't block the user — return an empty result so the
      # keyword scanner's verdict stands alone.
      Moderation::Result.empty
    end

    def self.cache_key(text)
      "moderation:ai:v#{VERSION}:#{Digest::SHA256.hexdigest(text)}"
    end

    def self.build_result(response)
      parsed = response.json
      issues = Array(parsed["issues"]).map do |h|
        {
          category: h["category"].to_s,
          phrase:   h["phrase"].to_s,
          severity: h["severity"].to_s,
          reason:   h["reason"].to_s,
          source:   :ai
        }
      end

      Moderation::Result.new(
        risk: normalize_risk(parsed["risk"]),
        issues: issues,
        suggested_rewrite: parsed["suggested_rewrite"].presence,
        scanner_versions: { ai: VERSION },
        scanned_at: Time.current
      )
    rescue JSON::ParserError => e
      Rails.logger.warn("[moderation ai] JSON parse error: #{e.message} — text=#{response.text.truncate(200)}")
      Moderation::Result.empty
    end

    VALID_RISKS = %w[low medium high blocked].freeze

    def self.normalize_risk(risk)
      return "low" if risk.blank?
      normalized = risk.to_s.downcase
      VALID_RISKS.include?(normalized) ? normalized : "low"
    end
  end
end
