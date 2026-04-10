require "test_helper"

class ShopScopedTest < ActiveSupport::TestCase
  setup do
    @alpha = shops(:alpha)
    @beta  = shops(:beta)
  end

  teardown do
    Current.reset
  end

  test "Campaign default_scope filters by Current.shop" do
    Current.shop = @alpha
    a = Campaign.create!(name: "Alpha Q1")

    Current.shop = @beta
    b = Campaign.create!(name: "Beta Spring")

    Current.shop = @alpha
    visible = Campaign.pluck(:id)
    assert_equal [a.id], visible, "Alpha should only see its own campaign"

    Current.shop = @beta
    visible = Campaign.pluck(:id)
    assert_equal [b.id], visible, "Beta should only see its own campaign"
  end

  test "Campaign auto-assigns Current.shop on create" do
    Current.shop = @alpha
    c = Campaign.create!(name: "Auto")
    assert_equal @alpha.id, c.shop_id
  end

  test "for_shop bypasses default_scope explicitly" do
    Current.shop = @alpha
    a = Campaign.create!(name: "Alpha")
    Current.shop = @beta
    b = Campaign.create!(name: "Beta")

    Current.shop = @alpha
    cross = Campaign.for_shop(@beta).pluck(:id)
    assert_equal [b.id], cross
  end

  test "cross_tenant scope returns rows from all shops" do
    Current.shop = @alpha
    Campaign.create!(name: "A")
    Current.shop = @beta
    Campaign.create!(name: "B")

    Current.shop = @alpha
    assert_equal 2, Campaign.cross_tenant.count
    assert_equal 1, Campaign.count
  end

  test "cross-tenant find raises ActiveRecord::RecordNotFound" do
    Current.shop = @alpha
    a = Campaign.create!(name: "Alpha only")

    Current.shop = @beta
    assert_raises(ActiveRecord::RecordNotFound) do
      Campaign.find(a.id)
    end
  end

  test "default_scope holds across joins and includes" do
    Current.shop = @alpha
    creator = Creator.create!(external_id: "ext_1", handle: "alpha_creator")
    campaign_a = Campaign.create!(name: "A")
    invite_a = Invite.create!(creator: creator, campaign: campaign_a)

    Current.shop = @beta
    campaign_b = Campaign.create!(name: "B")
    invite_b = Invite.create!(creator: creator, campaign: campaign_b)

    Current.shop = @alpha
    visible = Invite.includes(:campaign).pluck(:id)
    assert_equal [invite_a.id], visible

    visible_join = Invite.joins(:campaign).pluck(:id)
    assert_equal [invite_a.id], visible_join
  end

  test "Sample also respects shop scoping" do
    Current.shop = @alpha
    creator = Creator.create!(external_id: "ext_2", handle: "x")
    campaign = Campaign.create!(name: "A camp")
    invite = Invite.create!(creator: creator, campaign: campaign)
    sample_a = Sample.create!(invite: invite)

    Current.shop = @beta
    creator2 = Creator.create!(external_id: "ext_3", handle: "y")
    campaign_b = Campaign.create!(name: "B camp")
    invite_b = Invite.create!(creator: creator2, campaign: campaign_b)
    sample_b = Sample.create!(invite: invite_b)

    Current.shop = @alpha
    assert_equal [sample_a.id], Sample.pluck(:id)
    Current.shop = @beta
    assert_equal [sample_b.id], Sample.pluck(:id)
  end

  test "TiktokToken is unique per shop" do
    Current.shop = @alpha
    TiktokToken.create!(
      external_shop_id: "tt_alpha",
      access_token: "a",
      refresh_token: "r",
      access_expires_at: 1.hour.from_now,
      refresh_expires_at: 30.days.from_now
    )

    assert_raises(ActiveRecord::RecordInvalid) do
      TiktokToken.create!(
        external_shop_id: "tt_alpha_2",
        access_token: "a2",
        refresh_token: "r2",
        access_expires_at: 1.hour.from_now,
        refresh_expires_at: 30.days.from_now
      )
    end
  end

  test "Creator is global (not shop-scoped)" do
    Current.shop = @alpha
    c = Creator.create!(external_id: "global_1", handle: "anyone")

    Current.shop = @beta
    assert_equal c.id, Creator.find_by(external_id: "global_1").id, "Beta should also see globally cached creators"
  end

  test "with no Current.shop set, default_scope is inert" do
    Current.shop = @alpha
    Campaign.create!(name: "A")
    Current.shop = @beta
    Campaign.create!(name: "B")

    Current.reset
    # Without Current.shop the where clause is skipped
    assert_equal 2, Campaign.count
  end
end
