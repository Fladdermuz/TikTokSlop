require "test_helper"

class Shop::CreatorsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @shop = shops(:alpha)
    Membership.find_or_create_by!(user: @user, shop: @shop) do |m|
      m.role = "owner"
      m.joined_at = Time.current
    end

    Creator.delete_all
    @c1 = Creator.create!(external_id: "c1", handle: "alpha1", follower_count: 10_000, gmv_cents: 1_500_000, gmv_tier: "10k_100k", country: "US")
    @c2 = Creator.create!(external_id: "c2", handle: "alpha2", follower_count: 50_000, gmv_cents: 7_500_000, gmv_tier: "10k_100k", country: "US")

    sign_in_as(@user)
  end

  teardown { Current.reset }

  test "index renders the creator table" do
    get shop_creators_path
    assert_response :success
    assert_includes response.body, "alpha1"
    assert_includes response.body, "alpha2"
    assert_includes response.body, "matching creators"
  end

  test "index applies GMV filter" do
    get shop_creators_path, params: { min_gmv_dollars: "60000" }
    assert_response :success
    assert_includes response.body, "alpha2"
    refute_includes response.body, ">alpha1<"  # rough check — the row link
  end

  test "show renders creator detail" do
    get shop_creator_path(@c1)
    assert_response :success
    assert_includes response.body, "alpha1"
    assert_includes response.body, "Outreach history"
  end

  test "export returns CSV with selected creators" do
    post export_shop_creators_path, params: { creator_ids: [ @c1.id, @c2.id ] }
    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_match(/attachment; filename=/, response.headers["Content-Disposition"])
    assert_includes response.body, "alpha1"
    assert_includes response.body, "alpha2"
    assert_includes response.body, "handle,display_name,follower_count"
  end

  test "redirects unauthenticated user to login" do
    sign_out
    get shop_creators_path
    assert_redirected_to new_session_path
  end
end
