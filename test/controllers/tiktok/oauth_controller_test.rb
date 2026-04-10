require "test_helper"

class Tiktok::OauthControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @shop = shops(:alpha)
    Membership.find_or_create_by!(user: @user, shop: @shop) do |m|
      m.role = "owner"
      m.joined_at = Time.current
    end
    sign_in_as(@user)
  end

  teardown do
    Current.reset
  end

  test "successful callback persists encrypted token and redirects to dashboard" do
    pair = Tiktok::Types::TokenPair.new(
      access_token: "live_access_xxx",
      refresh_token: "live_refresh_xxx",
      access_expires_at: 7.days.from_now,
      refresh_expires_at: 365.days.from_now,
      seller_name: "Acme Seller",
      open_id: "open_acme_1",
      raw: { "seller_id" => "seller_acme_1" }
    )

    state = Tiktok::Resources::Authorization.build_state(shop_id: @shop.id, user_id: @user.id)

    stub_method(Tiktok::Resources::Authorization, :exchange_code, ->(code) { assert_equal "auth_code_123", code; pair }) do
      stub_method(Tiktok::Resources::Shop, :first_for, nil) do
        get tiktok_callback_path, params: { code: "auth_code_123", state: state }
      end
    end

    assert_redirected_to shop_dashboard_path
    assert_equal "TikTok Shop connected for #{@shop.name}.", flash[:notice]

    token = @shop.reload.tiktok_token
    assert token.present?
    assert_equal "live_access_xxx", token.access_token
    assert_equal "live_refresh_xxx", token.refresh_token
    assert_equal "Acme Seller", token.seller_name
  end

  test "callback with tampered state redirects with error" do
    state = Tiktok::Resources::Authorization.build_state(shop_id: @shop.id, user_id: @user.id)
    tampered = state.sub(/.\z/, "X")

    get tiktok_callback_path, params: { code: "abc", state: tampered }
    assert_response :redirect
    assert_match(/invalid or expired/i, flash[:alert])
  end

  test "callback with missing code redirects with error" do
    state = Tiktok::Resources::Authorization.build_state(shop_id: @shop.id, user_id: @user.id)
    get tiktok_callback_path, params: { state: state }
    assert_response :redirect
    assert_match(/code missing/i, flash[:alert])
  end

  test "callback rejects state from a different user" do
    other = users(:two)
    state = Tiktok::Resources::Authorization.build_state(shop_id: @shop.id, user_id: other.id)
    get tiktok_callback_path, params: { code: "abc", state: state }
    assert_response :redirect
    assert_match(/user mismatch/i, flash[:alert])
  end

  test "callback rejects shop the current user is not a member of" do
    state = Tiktok::Resources::Authorization.build_state(shop_id: shops(:beta).id, user_id: @user.id)
    get tiktok_callback_path, params: { code: "abc", state: state }
    assert_response :redirect
    assert_match(/no longer available/i, flash[:alert])
  end

  test "callback handles AuthError from token exchange" do
    state = Tiktok::Resources::Authorization.build_state(shop_id: @shop.id, user_id: @user.id)
    stub_method(Tiktok::Resources::Authorization, :exchange_code, ->(_) { raise Tiktok::AuthError.new("invalid auth_code", code: 36004003) }) do
      get tiktok_callback_path, params: { code: "bad", state: state }
    end
    assert_response :redirect
    assert_match(/TikTok rejected/i, flash[:alert])
    assert_nil @shop.reload.tiktok_token
  end
end
