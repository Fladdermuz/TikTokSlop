require "test_helper"

class Moderation::ScannerTest < ActiveSupport::TestCase
  setup do
    @shop = shops(:alpha)
  end

  teardown { Current.reset }

  test "short-circuits on keyword-level blocked risk (no AI call)" do
    ai_called = false
    stub_method(Moderation::AiScanner, :scan, ->(_, **_) { ai_called = true; Moderation::Result.empty }) do
      result = Moderation::Scanner.scan("Guaranteed payout of $1000/day!", shop: @shop)
      assert_equal "blocked", result.risk
      refute ai_called, "AiScanner must not be called after keyword-level block"
    end
  end

  test "merges keyword + AI results when keyword result is not blocked" do
    fake_ai_result = Moderation::Result.new(
      risk: "high",
      issues: [ { category: "health_claims", phrase: "miracle serum", severity: "high", reason: "implied", source: :ai } ],
      suggested_rewrite: "Hey! Check out our new serum.",
      scanner_versions: { ai: 1 },
      scanned_at: Time.current
    )

    stub_method(Moderation::AiScanner, :scan, ->(_, **_) { fake_ai_result }) do
      result = Moderation::Scanner.scan("Act now! Our amazing serum is here.", shop: @shop)
      # Keyword catches "act now" (medium); AI adds "miracle serum" (high) → merged high
      assert_equal "high", result.risk
      sources = result.issues.map { |i| i[:source].to_s }
      assert_includes sources, "keyword_phrase"
      assert_includes sources, "ai"
      assert_equal "Hey! Check out our new serum.", result.suggested_rewrite
    end
  end

  test "use_ai: false skips the AI scanner entirely" do
    ai_called = false
    stub_method(Moderation::AiScanner, :scan, ->(_, **_) { ai_called = true; Moderation::Result.empty }) do
      Moderation::Scanner.scan("Hi! Simple friendly message.", shop: @shop, use_ai: false)
      refute ai_called
    end
  end

  test "scan_and_persist creates a ModerationCheck row tied to the checkable" do
    Current.shop = @shop
    product = Product.create!(name: "Test", price_cents: 100, status: "active")
    campaign = Campaign.create!(name: "Scan persist", product: product, message_template: "Clean friendly hi")
    Current.reset

    stub_method(Moderation::AiScanner, :scan, ->(_, **_) { Moderation::Result.empty }) do
      result = Moderation::Scanner.scan_and_persist("Clean friendly hi", shop: @shop, checkable: campaign)
      assert_equal "low", result.risk
    end

    persisted = ModerationCheck.cross_tenant.latest_for(campaign).first
    assert persisted.present?
    assert_equal "low", persisted.risk
    assert_equal "Clean friendly hi", persisted.checked_text
    assert_equal campaign.id, persisted.checkable_id
    assert_equal "Campaign", persisted.checkable_type
  end
end
