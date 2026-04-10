require "test_helper"

class CampaignTest < ActiveSupport::TestCase
  setup do
    @shop = shops(:alpha)
    Current.shop = @shop
    @product = Product.create!(name: "Test Serum", price_cents: 1999, status: "active")
    @campaign = Campaign.create!(name: "Spring", product: @product, commission_rate: 0.15)
  end

  teardown { Current.reset }

  test "new campaigns start in draft" do
    assert_equal "draft", @campaign.status
    assert @campaign.draft?
  end

  test "transition_to respects allowed transitions" do
    assert @campaign.transition_to!("active")
    assert @campaign.reload.active?

    assert @campaign.transition_to!("paused")
    assert @campaign.reload.paused?

    assert @campaign.transition_to!("active")
    assert @campaign.reload.active?

    assert @campaign.transition_to!("ended")
    assert @campaign.reload.ended?
  end

  test "transition_to rejects invalid transitions" do
    refute @campaign.transition_to!("paused")  # draft → paused not allowed
    assert @campaign.errors[:status].any?
    assert_equal "draft", @campaign.reload.status
  end

  test "ended is terminal" do
    @campaign.transition_to!("active")
    @campaign.transition_to!("ended")
    refute @campaign.transition_to!("active")
    refute @campaign.transition_to!("paused")
  end

  test "editable_fields changes per lifecycle state" do
    assert_includes @campaign.editable_fields, "name"
    assert_includes @campaign.editable_fields, "commission_rate"

    @campaign.transition_to!("active")
    refute_includes @campaign.editable_fields, "name"
    refute_includes @campaign.editable_fields, "commission_rate"
    assert_includes @campaign.editable_fields, "message_template"

    @campaign.transition_to!("ended")
    assert_empty @campaign.editable_fields
  end

  test "requires a product" do
    c = Campaign.new(name: "No product")
    refute c.valid?
    assert c.errors[:product].any?
  end
end
