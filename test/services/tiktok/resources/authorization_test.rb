require "test_helper"

class Tiktok::Resources::AuthorizationTest < ActiveSupport::TestCase
  test "build_state and verify_state round trip" do
    token = Tiktok::Resources::Authorization.build_state(shop_id: 42, user_id: 7)
    payload = Tiktok::Resources::Authorization.verify_state(token).symbolize_keys

    assert_equal 42, payload[:shop_id]
    assert_equal 7,  payload[:user_id]
    assert payload[:nonce].present?
    assert payload[:iat].present?
  end

  test "verify_state raises on tampered token" do
    token = Tiktok::Resources::Authorization.build_state(shop_id: 1, user_id: 1)
    tampered = token.sub(/.\z/, "X")  # flip the last character
    assert_raises(ActiveSupport::MessageVerifier::InvalidSignature) do
      Tiktok::Resources::Authorization.verify_state(tampered)
    end
  end

  test "authorize_url contains app_key, state, and redirect_uri" do
    token = Tiktok::Resources::Authorization.build_state(shop_id: 1, user_id: 1)
    url = Tiktok::Resources::Authorization.authorize_url(state: token)

    uri = URI(url)
    query = URI.decode_www_form(uri.query).to_h
    assert_equal "auth.tiktok-shops.com", uri.host
    assert_equal "/oauth/authorize", uri.path
    assert_equal token, query["state"]
    assert query["redirect_uri"].present?
    # app_key may be blank in test credentials, but the param must exist
    assert query.key?("app_key")
  end
end
