# Top-level moderation entry point. Runs the fast keyword scanner first;
# only calls the AI scanner if the keyword scanner didn't already hard-block.
#
# Returns a merged Moderation::Result combining both scanners' findings.
#
# Usage:
#   result = Moderation::Scanner.scan("Hey {{creator.handle}}!...", shop: current_shop)
#   result.blocked?   # => true/false
#   result.issues     # => [{category, phrase, severity, reason, source}, ...]
module Moderation
  class Scanner
    def self.scan(text, shop:, use_ai: true)
      keyword_result = Moderation::KeywordScanner.scan(text)

      # Short-circuit if the keyword scanner is already confident the message
      # is blocked or high-risk — no point spending an AI call.
      return keyword_result if keyword_result.blocked?
      return keyword_result unless use_ai

      ai_result = Moderation::AiScanner.scan(text, shop: shop)
      keyword_result.merge(ai_result)
    end

    # Persist a result against a subject (Campaign, Invite, etc.).
    def self.scan_and_persist(text, shop:, checkable:, use_ai: true)
      result = scan(text, shop: shop, use_ai: use_ai)
      ModerationCheck.cross_tenant.create!(
        shop: shop,
        checkable: checkable,
        checked_text: text,
        risk: result.risk,
        issues: result.issues.map(&:stringify_keys),
        suggested_rewrite: result.suggested_rewrite,
        scanner_versions: result.scanner_versions.stringify_keys
      )
      result
    end
  end
end
