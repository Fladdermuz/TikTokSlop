require "test_helper"

class Moderation::AiScannerTest < ActiveSupport::TestCase
  setup do
    @shop = shops(:alpha)
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  test "parses a valid AI JSON response" do
    fake_response = Ai::Response.new(
      text: '{"risk":"high","issues":[{"phrase":"miracle cure","category":"health_claims","severity":"high","reason":"unproven medical claim"}],"suggested_rewrite":"Check out our supplement."}',
      model: "claude-haiku-4-5",
      input_tokens: 100, output_tokens: 50, request_id: "req_test", raw: nil
    )

    stub_method(Ai::Client, :new, ->(**_) { FakeAiClient.new(fake_response) }) do
      result = Moderation::AiScanner.scan("our miracle cure works instantly", shop: @shop)
      assert_equal "high", result.risk
      assert_equal 1, result.issues.size
      assert_equal "health_claims", result.issues.first[:category]
      assert_equal :ai, result.issues.first[:source]
      assert_equal "Check out our supplement.", result.suggested_rewrite
    end
  end

  test "handles JSON wrapped in markdown fences" do
    fake_response = Ai::Response.new(
      text: "```json\n{\"risk\":\"low\",\"issues\":[]}\n```",
      model: "claude-haiku-4-5",
      input_tokens: 10, output_tokens: 5, request_id: "req", raw: nil
    )
    stub_method(Ai::Client, :new, ->(**_) { FakeAiClient.new(fake_response) }) do
      result = Moderation::AiScanner.scan("hi", shop: @shop)
      assert_equal "low", result.risk
    end
  end

  test "returns empty result when JSON parse fails" do
    fake_response = Ai::Response.new(
      text: "I cannot comply with this request",  # not JSON
      model: "claude-haiku-4-5",
      input_tokens: 10, output_tokens: 5, request_id: "req", raw: nil
    )
    stub_method(Ai::Client, :new, ->(**_) { FakeAiClient.new(fake_response) }) do
      result = Moderation::AiScanner.scan("hi", shop: @shop)
      assert_equal "low", result.risk
      assert_empty result.issues
    end
  end

  test "returns empty result when API raises an error" do
    error_client = Object.new
    def error_client.complete(**_)
      raise Ai::Client::ServerError, "upstream down"
    end

    stub_method(Ai::Client, :new, ->(**_) { error_client }) do
      result = Moderation::AiScanner.scan("hi", shop: @shop)
      assert_equal "low", result.risk
    end
  end

  test "caches results by message hash" do
    call_count = 0
    fake_response = Ai::Response.new(
      text: '{"risk":"low","issues":[]}',
      model: "claude-haiku-4-5",
      input_tokens: 10, output_tokens: 5, request_id: "req", raw: nil
    )
    fake_client = Object.new
    fake_client.define_singleton_method(:complete) { |**_| call_count += 1; fake_response }

    stub_method(Ai::Client, :new, ->(**_) { fake_client }) do
      Moderation::AiScanner.scan("hello world", shop: @shop)
      Moderation::AiScanner.scan("hello world", shop: @shop)
      Moderation::AiScanner.scan("hello world", shop: @shop)
    end

    assert_equal 1, call_count, "expected second/third scans to hit the cache"
  end

  # Minimal stand-in for Ai::Client used by the stubs.
  class FakeAiClient
    def initialize(response); @response = response; end
    def complete(**_); @response; end
  end
end
