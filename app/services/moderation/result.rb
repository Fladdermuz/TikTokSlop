module Moderation
  Result = Data.define(:risk, :issues, :suggested_rewrite, :scanner_versions, :scanned_at) do
    def self.empty
      new(risk: "low", issues: [], suggested_rewrite: nil, scanner_versions: {}, scanned_at: Time.current)
    end

    def blocked?; risk == "blocked"; end
    def high?;    risk == "high";    end
    def medium?;  risk == "medium";  end
    def low?;     risk == "low";     end

    def passable?
      risk.in?(%w[low medium])
    end

    # Merge in a second scanner's output. The higher severity wins.
    def merge(other)
      return self if other.nil?
      merged_risk = worst_of(risk, other.risk)
      self.class.new(
        risk: merged_risk,
        issues: issues + other.issues,
        suggested_rewrite: suggested_rewrite || other.suggested_rewrite,
        scanner_versions: scanner_versions.merge(other.scanner_versions),
        scanned_at: [ scanned_at, other.scanned_at ].max
      )
    end

    private

    def worst_of(a, b)
      order = { "low" => 0, "medium" => 1, "high" => 2, "blocked" => 3 }
      order[a] > order[b] ? a : b
    end
  end
end
