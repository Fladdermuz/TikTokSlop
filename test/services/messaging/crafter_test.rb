require "test_helper"

class Messaging::CrafterTest < ActiveSupport::TestCase
  setup do
    @shop = shops(:alpha)
    Current.shop = @shop
    @product = Product.create!(name: "Vitamin C Serum", price_cents: 2499, status: "active")
    @product.create_knowledge!(
      short_description: "High-potency Vitamin C serum for brighter skin.",
      ingredients: "L-Ascorbic Acid (20%), Hyaluronic Acid, Vitamin E",
      benefits: "Brightens skin tone\nReduces dark spots",
      target_audience: "Skincare creators, women 25-45",
      usp: "20% concentration with ferulic acid",
      brand_name: "Bionox",
      brand_voice: "Friendly, science-backed"
    )
    @campaign = Campaign.create!(name: "Spring Glow", product: @product, commission_rate: 0.15, sample_offer: true)
    @creator = Creator.create!(external_id: "cr_betty", handle: "beautybyamy", display_name: "Amy Beauty", follower_count: 85_000, categories: %w[beauty skincare], country: "US")

    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Current.reset
    @original_cache = nil
  end

  test "template_for generates a message with product references" do
    fake_ai = build_fake_client("Hey {{creator.handle}}! We'd love to send you our Vitamin C Serum with 20% L-ascorbic acid. 15.0% commission — interested?")

    stub_method(Ai::Client, :new, ->(**_) { fake_ai }) do
      stub_method(Moderation::AiScanner, :scan, ->(_, **_) { Moderation::Result.empty }) do
        result = Messaging::Crafter.template_for(campaign: @campaign, shop: @shop)
        assert result.text.include?("Vitamin C")
        assert result.moderation_result.passable?
        assert_equal 0, result.retries_used
      end
    end
  end

  test "personalized_for generates a message referencing the specific creator" do
    fake_ai = build_fake_client("Hey Amy! Love your skincare content — you'd be perfect for our Vitamin C Serum review. We have an exclusive 15% commission. Interested?")

    stub_method(Ai::Client, :new, ->(**_) { fake_ai }) do
      stub_method(Moderation::AiScanner, :scan, ->(_, **_) { Moderation::Result.empty }) do
        result = Messaging::Crafter.personalized_for(campaign: @campaign, creator: @creator, shop: @shop)
        assert result.text.include?("Amy")
        assert result.text.include?("Vitamin C Serum")
      end
    end
  end

  test "retries when moderation flags the generated text" do
    call_count = 0
    fake_ai = Object.new
    fake_ai.define_singleton_method(:complete) do |**_|
      call_count += 1
      text = call_count == 1 ? "Guaranteed payout! WhatsApp me" : "Hey! Try our serum — great commission."
      Ai::Response.new(text: text, model: "haiku", input_tokens: 10, output_tokens: 10, request_id: "r", raw: nil)
    end

    stub_method(Ai::Client, :new, ->(**_) { fake_ai }) do
      # Use real keyword scanner but stub AI scanner
      stub_method(Moderation::AiScanner, :scan, ->(_, **_) { Moderation::Result.empty }) do
        result = Messaging::Crafter.template_for(campaign: @campaign, shop: @shop)
        assert result.moderation_result.passable?, "final result should be passable after retry"
        assert_equal 1, result.retries_used
        assert_equal 2, call_count
      end
    end
  end

  test "caches template results" do
    call_count = 0
    fake_ai = Object.new
    fake_ai.define_singleton_method(:complete) do |**_|
      call_count += 1
      Ai::Response.new(text: "Hello! Try our serum.", model: "haiku", input_tokens: 10, output_tokens: 10, request_id: "r", raw: nil)
    end

    stub_method(Ai::Client, :new, ->(**_) { fake_ai }) do
      stub_method(Moderation::AiScanner, :scan, ->(_, **_) { Moderation::Result.empty }) do
        Messaging::Crafter.template_for(campaign: @campaign, shop: @shop)
        Messaging::Crafter.template_for(campaign: @campaign, shop: @shop)
        assert_equal 1, call_count, "second call should hit cache"
      end
    end
  end

  private

  def build_fake_client(text)
    client = Object.new
    response = Ai::Response.new(text: text, model: "claude-sonnet-4-6", input_tokens: 100, output_tokens: 80, request_id: "req_test", raw: nil)
    client.define_singleton_method(:complete) { |**_| response }
    client
  end
end
