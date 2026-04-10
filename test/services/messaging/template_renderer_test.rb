require "test_helper"
require "ostruct"

class Messaging::TemplateRendererTest < ActiveSupport::TestCase
  setup do
    @creator = OpenStruct.new(handle: "betty", display_name: "Betty B", country: "US", categories: %w[beauty skincare])
    @campaign = OpenStruct.new(name: "Spring Glow", commission_rate: 0.15)
    @shop = OpenStruct.new(name: "Tikedon HQ")
    @product = OpenStruct.new(name: "Vitamin C Serum")
  end

  test "substitutes all known variables" do
    tmpl = "Hey {{creator.handle}} ({{creator.display_name}})! Love your {{creator.top_category}} content. Try {{product.name}} from {{shop.name}} at {{campaign.commission_pct}}."
    result = Messaging::TemplateRenderer.render(tmpl, creator: @creator, campaign: @campaign, shop: @shop, product: @product)
    assert_equal "Hey betty (Betty B)! Love your beauty content. Try Vitamin C Serum from Tikedon HQ at 15.0%.", result
  end

  test "tolerates whitespace inside braces" do
    assert_equal "Hi betty", Messaging::TemplateRenderer.render("Hi {{  creator.handle  }}", creator: @creator)
  end

  test "unknown variables render as empty string in lenient mode" do
    assert_equal "Hi ", Messaging::TemplateRenderer.render("Hi {{creator.ssn}}", creator: @creator)
  end

  test "unknown variables raise in strict mode" do
    assert_raises(Messaging::TemplateRenderer::UnknownVariableError) do
      Messaging::TemplateRenderer.render("{{creator.ssn}}", strict: true, creator: @creator)
    end
  end

  test "variables_in returns all distinct variables referenced" do
    tmpl = "{{creator.handle}} and {{creator.handle}} and {{shop.name}}"
    assert_equal %w[creator.handle shop.name], Messaging::TemplateRenderer.variables_in(tmpl)
  end

  test "unknown_variables_in only lists ones not in whitelist" do
    tmpl = "{{creator.handle}} {{creator.bogus}} {{shop.fakekey}}"
    unknown = Messaging::TemplateRenderer.unknown_variables_in(tmpl)
    assert_equal %w[creator.bogus shop.fakekey], unknown
  end

  test "nil context values render as empty string" do
    result = Messaging::TemplateRenderer.render("Hey {{creator.handle}}", creator: nil)
    assert_equal "Hey ", result
  end

  test "commission_pct is nil-safe" do
    campaign = OpenStruct.new(name: "X", commission_rate: nil)
    assert_equal "", Messaging::TemplateRenderer.render("{{campaign.commission_pct}}", campaign: campaign)
  end

  test "does not interpret non-matching curly braces" do
    assert_equal "Hello {world}", Messaging::TemplateRenderer.render("Hello {world}")
  end
end
