require "test_helper"

class Moderation::KeywordScannerTest < ActiveSupport::TestCase
  test "clean message returns low risk with no issues" do
    result = Moderation::KeywordScanner.scan("Hey! Love your skincare content. We would love to send you our Vitamin C Serum to try.")
    assert_equal "low", result.risk
    assert_empty result.issues
  end

  test "hard block on guaranteed income phrase" do
    result = Moderation::KeywordScanner.scan("Guaranteed payout of thousands per month")
    assert_equal "blocked", result.risk
    assert result.issues.any? { |i| i[:category] == "income_claims" }
  end

  test "hard block on off-platform redirect phrase" do
    result = Moderation::KeywordScanner.scan("Message me on WhatsApp instead")
    assert_equal "blocked", result.risk
    assert result.issues.any? { |i| i[:category] == "external_platforms" }
  end

  test "medium risk on spam markers only" do
    result = Moderation::KeywordScanner.scan("Act now for our limited time exclusive offer!")
    assert_equal "medium", result.risk
    refute result.issues.empty?
    assert result.issues.all? { |i| i[:severity] == "medium" }
  end

  test "dollar-per-day pattern is detected" do
    result = Moderation::KeywordScanner.scan("You can earn $500 per day with us")
    assert_equal "blocked", result.risk
    phrases = result.issues.map { |i| i[:phrase] }
    assert phrases.any? { |p| p.include?("$500") }
  end

  test "phone number pattern is detected" do
    result = Moderation::KeywordScanner.scan("Call 555-123-4567 today")
    assert_equal "blocked", result.risk
    assert result.issues.any? { |i| i[:category] == "contact_info" }
  end

  test "email pattern is detected (case-insensitive)" do
    result = Moderation::KeywordScanner.scan("Reach Matt at Matt@Example.COM")
    assert_equal "blocked", result.risk
    assert result.issues.any? { |i| i[:category] == "contact_info" }
  end

  test "lowercase text does not trigger uppercase-shouty pattern" do
    result = Moderation::KeywordScanner.scan("beautybyamy skincare content from creator")
    refute result.issues.any? { |i| i[:phrase] =~ /[A-Z]/ }, "uppercase pattern matched lowercase text"
  end

  test "real shouty UPPERCASE (6+ caps in a row) triggers spam marker" do
    result = Moderation::KeywordScanner.scan("AMAZING deal for you today")
    assert result.issues.any? { |i| i[:category] == "spam_markers" }, "expected AMAZING (7 caps) to match the shouty pattern"
  end

  test "empty text returns low risk with no issues" do
    result = Moderation::KeywordScanner.scan("")
    assert_equal "low", result.risk
    assert_empty result.issues
  end

  test "scanner version is captured in scanner_versions" do
    result = Moderation::KeywordScanner.scan("hello")
    assert_includes result.scanner_versions.keys, :keyword
  end
end
