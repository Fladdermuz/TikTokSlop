require "test_helper"

class Shop::CampaignsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @shop = shops(:alpha)
    Membership.find_or_create_by!(user: @user, shop: @shop) do |m|
      m.role = "owner"
      m.joined_at = Time.current
    end

    Current.shop = @shop
    @product = Product.create!(name: "Test", price_cents: 1000, status: "active")
    @campaign = Campaign.create!(name: "Spring", product: @product, commission_rate: 0.15)
    Current.reset

    sign_in_as(@user)
  end

  teardown { Current.reset }

  test "index lists campaigns" do
    get shop_campaigns_path
    assert_response :success
    assert_includes response.body, "Spring"
  end

  test "show displays campaign detail with status badge" do
    get shop_campaign_path(@campaign)
    assert_response :success
    assert_includes response.body, "Spring"
    assert_includes response.body, "draft"
  end

  test "new requires product to exist — shows form anyway with warning" do
    get new_shop_campaign_path
    assert_response :success
    assert_includes response.body, "Pick a product"
  end

  test "create validates required fields" do
    post shop_campaigns_path, params: { campaign: { name: "", product_id: @product.id } }
    assert_response :unprocessable_entity
  end

  test "create successful in draft state" do
    post shop_campaigns_path, params: { campaign: { name: "Summer", product_id: @product.id, commission_rate: 0.1 } }
    assert_response :redirect
    new_campaign = Campaign.unscoped.find_by(name: "Summer")
    assert new_campaign.present?
    assert_equal "draft", new_campaign.status
  end

  test "transition endpoint moves campaign forward" do
    post transition_shop_campaign_path(@campaign, to: "active")
    assert_redirected_to shop_campaign_path(@campaign)
    assert_equal "active", @campaign.reload.status
  end

  test "transition endpoint rejects invalid transition" do
    post transition_shop_campaign_path(@campaign, to: "ended")
    assert_redirected_to shop_campaign_path(@campaign)
    assert_equal "draft", @campaign.reload.status  # unchanged
    follow_redirect!
    assert_match(/cannot transition/i, response.body)
  end

  test "edit page is shown for draft; ended redirects" do
    get edit_shop_campaign_path(@campaign)
    assert_response :success

    # End it and try to edit
    @campaign.update!(status: "ended")
    get edit_shop_campaign_path(@campaign)
    assert_redirected_to shop_campaign_path(@campaign)
    assert_match(/read-only/i, flash[:alert])
  end

  test "update in active state only changes message_template and notes" do
    @campaign.update!(status: "active")
    patch shop_campaign_path(@campaign), params: { campaign: { name: "Renamed", message_template: "New template", notes: "Keep it up" } }
    assert_redirected_to shop_campaign_path(@campaign)
    @campaign.reload
    assert_equal "Spring", @campaign.name  # unchanged
    assert_equal "New template", @campaign.message_template
    assert_equal "Keep it up", @campaign.notes
  end

  test "destroy refuses if invites exist" do
    creator = Creator.create!(external_id: "test_c1", handle: "c1")
    Current.shop = @shop
    Invite.create!(creator: creator, campaign: @campaign)
    Current.reset

    delete shop_campaign_path(@campaign)
    assert_redirected_to shop_campaign_path(@campaign)
    assert Campaign.unscoped.exists?(@campaign.id)
  end
end
