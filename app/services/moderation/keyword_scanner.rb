# Fast first-line moderation check. No API calls — pure Ruby regex/substring
# match against the curated banned-keyword list in config/tiktok_banned_keywords.yml.
#
# Sub-millisecond typical, called on every message before sending to TikTok and
# live in the campaign editor as the user types.
#
# Usage:
#   Moderation::KeywordScanner.scan("Guaranteed payout of $500/day!")
#   # => Moderation::Result with risk: :high and hit list
module Moderation
  class KeywordScanner
    CONFIG_PATH = Rails.root.join("config/tiktok_banned_keywords.yml")

    class << self
      def scan(text)
        return Moderation::Result.empty if text.blank?
        text = text.to_s

        hits = []
        config["categories"].each do |category_name, category|
          severity = category["severity"]
          note     = category["note"]

          Array(category["phrases"]).each do |phrase|
            if text.downcase.include?(phrase.downcase)
              hits << build_hit(category: category_name, phrase: phrase, severity: severity, note: note, source: :keyword_phrase, snippet: text)
            end
          end

          Array(category["patterns"]).each do |pattern_source|
            # Patterns are case-sensitive by default (so `[A-Z]{6,}` means
            # real uppercase, not any letters). Prefix with `(?i)` in the YAML
            # for case-insensitive.
            regex = Regexp.new(pattern_source)
            text.scan(regex) do |match|
              matched = match.is_a?(Array) ? match.first : match
              hits << build_hit(category: category_name, phrase: matched, severity: severity, note: note, source: :keyword_pattern, snippet: text)
            end
          end
        end

        Moderation::Result.new(
          risk: risk_from_hits(hits),
          issues: hits,
          suggested_rewrite: nil,
          scanner_versions: { keyword: config["scanner_version"] },
          scanned_at: Time.current
        )
      end

      def config
        @config ||= YAML.load_file(CONFIG_PATH)
      end

      def reload!
        @config = nil
        config
      end

      private

      def build_hit(category:, phrase:, severity:, note:, source:, snippet:)
        # Trim snippet to at most 60 chars centered on the match for readability
        lower = snippet.downcase
        idx = lower.index(phrase.to_s.downcase) || 0
        start = [ idx - 20, 0 ].max
        excerpt = snippet[start, 60]
        {
          category: category,
          phrase: phrase.to_s,
          severity: severity,
          reason: note,
          source: source,
          snippet: excerpt
        }
      end

      def risk_from_hits(hits)
        return "low" if hits.empty?
        severities = hits.map { |h| h[:severity] }.uniq
        return "blocked" if severities.include?("high")
        return "medium"  if severities.include?("medium")
        "low"
      end
    end
  end
end
