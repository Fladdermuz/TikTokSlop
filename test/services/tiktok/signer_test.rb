require "test_helper"

class Tiktok::SignerTest < ActiveSupport::TestCase
  APP_SECRET = "topsecret".freeze

  test "canonical string sorts keys ASCII order and joins as key+value" do
    canonical = Tiktok::Signer.canonical_string(
      "timestamp" => "1700000000",
      "app_key"   => "12345",
      "version"   => "202309"
    )
    assert_equal "app_key12345timestamp1700000000version202309", canonical
  end

  test "canonical string excludes signing-related keys" do
    canonical = Tiktok::Signer.canonical_string(
      "app_key"      => "12345",
      "sign"         => "deadbeef",
      "access_token" => "abc",
      "x-tts-access-token" => "abc2",
      "app_secret"   => "leak",
      "token"        => "tok"
    )
    assert_equal "app_key12345", canonical
  end

  test "canonical string handles symbol keys" do
    canonical = Tiktok::Signer.canonical_string(
      app_key: "12345",
      timestamp: "1700000000"
    )
    assert_equal "app_key12345timestamp1700000000", canonical
  end

  test "GET request signs path + sorted canonical string only (body is ignored)" do
    sig = Tiktok::Signer.sign(
      method: :get,
      path: "/api/orders/202309/list",
      query: { app_key: "12345", timestamp: "1700000000", version: "202309" },
      app_secret: APP_SECRET
    )
    expected_payload = "topsecret/api/orders/202309/listapp_key12345timestamp1700000000version202309topsecret"
    expected = OpenSSL::HMAC.hexdigest("sha256", APP_SECRET, expected_payload)
    assert_equal expected, sig
    assert_match(/\A[0-9a-f]{64}\z/, sig)
  end

  test "POST request appends body bytes when not multipart" do
    body = '{"campaign_id":"abc","creator_ids":["c1","c2"]}'
    sig = Tiktok::Signer.sign(
      method: :post,
      path: "/api/affiliate_seller/202405/targeted_collaborations/create",
      query: { app_key: "12345", timestamp: "1700000000" },
      body: body,
      app_secret: APP_SECRET
    )
    expected_payload = "topsecret/api/affiliate_seller/202405/targeted_collaborations/create" \
                       "app_key12345timestamp1700000000" \
                       "#{body}topsecret"
    expected = OpenSSL::HMAC.hexdigest("sha256", APP_SECRET, expected_payload)
    assert_equal expected, sig
  end

  test "POST request omits body when multipart: true" do
    body = "binary upload bytes"
    sig = Tiktok::Signer.sign(
      method: :post,
      path: "/api/products/202309/upload",
      query: { app_key: "12345", timestamp: "1700000000" },
      body: body,
      multipart: true,
      app_secret: APP_SECRET
    )
    expected_payload = "topsecret/api/products/202309/uploadapp_key12345timestamp1700000000topsecret"
    expected = OpenSSL::HMAC.hexdigest("sha256", APP_SECRET, expected_payload)
    assert_equal expected, sig
  end

  test "sign result is deterministic and lowercase hex" do
    args = {
      method: :get,
      path:   "/api/x/y/z",
      query:  { app_key: "k", timestamp: "1" },
      app_secret: APP_SECRET
    }
    a = Tiktok::Signer.sign(**args)
    b = Tiktok::Signer.sign(**args)
    assert_equal a, b
    assert_equal 64, a.length
    assert_match(/\A[0-9a-f]+\z/, a)
  end

  test "sorting is byte-wise (uppercase before lowercase)" do
    canonical = Tiktok::Signer.canonical_string("Z" => "1", "a" => "2")
    # ASCII: 'Z' (90) < 'a' (97)
    assert_equal "Z1a2", canonical
  end

  test "shop_cipher is included in signing (not excluded)" do
    canonical = Tiktok::Signer.canonical_string(
      "app_key"     => "k",
      "shop_cipher" => "TTPmcZAAAAAAA"
    )
    assert_equal "app_keykshop_cipherTTPmcZAAAAAAA", canonical
  end

  test "empty body on POST does not append anything" do
    sig_with_nil = Tiktok::Signer.sign(
      method: :post, path: "/api/x", query: { a: "1" }, body: nil, app_secret: APP_SECRET
    )
    sig_with_empty = Tiktok::Signer.sign(
      method: :post, path: "/api/x", query: { a: "1" }, body: "", app_secret: APP_SECRET
    )
    assert_equal sig_with_nil, sig_with_empty
  end

  test "body bytes must match exactly (whitespace sensitive)" do
    a = Tiktok::Signer.sign(method: :post, path: "/x", query: {}, body: '{"k":"v"}', app_secret: APP_SECRET)
    b = Tiktok::Signer.sign(method: :post, path: "/x", query: {}, body: '{ "k": "v" }', app_secret: APP_SECRET)
    refute_equal a, b, "different body whitespace must produce different signatures"
  end
end
