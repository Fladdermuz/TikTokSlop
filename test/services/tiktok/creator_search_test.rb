require "test_helper"

class Tiktok::CreatorSearchTest < ActiveSupport::TestCase
  setup do
    @shop = shops(:alpha)

    Creator.delete_all
    @low  = Creator.create!(external_id: "c_low",  handle: "lowfan",  follower_count: 5_000,   gmv_cents: 500_000,    gmv_tier: "under_10k",  country: "US", categories: %w[beauty])
    @mid  = Creator.create!(external_id: "c_mid",  handle: "midfan",  follower_count: 50_000,  gmv_cents: 5_000_000,  gmv_tier: "10k_100k",   country: "US", categories: %w[fitness])
    @high = Creator.create!(external_id: "c_high", handle: "highfan", follower_count: 800_000, gmv_cents: 80_000_000, gmv_tier: "500k_plus",  country: "CA", categories: %w[beauty fitness])
  end

  teardown do
    Current.reset
  end

  test "no filters returns all creators sorted by GMV desc" do
    filters = Tiktok::CreatorSearch::Filters.from_params({})
    result = Tiktok::CreatorSearch.new(shop: @shop, filters: filters).call
    assert_equal [ @high.id, @mid.id, @low.id ], result.pluck(:id)
  end

  test "min_gmv_dollars filters out lower-GMV creators" do
    # mid gmv is $50,000 exactly; high is $800,000. Use $60,000 to exclude mid.
    filters = Tiktok::CreatorSearch::Filters.from_params(min_gmv_dollars: "60000")
    result = Tiktok::CreatorSearch.new(shop: @shop, filters: filters).call
    assert_includes result, @high
    refute_includes result, @mid
    refute_includes result, @low
  end

  test "gmv_tier filters exactly to that tier" do
    filters = Tiktok::CreatorSearch::Filters.from_params(gmv_tier: "10k_100k")
    result = Tiktok::CreatorSearch.new(shop: @shop, filters: filters).call
    assert_equal [ @mid.id ], result.pluck(:id)
  end

  test "min_followers filter" do
    filters = Tiktok::CreatorSearch::Filters.from_params(min_followers: "100000")
    result = Tiktok::CreatorSearch.new(shop: @shop, filters: filters).call
    assert_equal [ @high.id ], result.pluck(:id)
  end

  test "country filter" do
    filters = Tiktok::CreatorSearch::Filters.from_params(country: "CA")
    result = Tiktok::CreatorSearch.new(shop: @shop, filters: filters).call
    assert_equal [ @high.id ], result.pluck(:id)
  end

  test "keyword filter (case-insensitive substring on handle)" do
    filters = Tiktok::CreatorSearch::Filters.from_params(keyword: "MID")
    result = Tiktok::CreatorSearch.new(shop: @shop, filters: filters).call
    assert_equal [ @mid.id ], result.pluck(:id)
  end

  test "sort by followers desc" do
    filters = Tiktok::CreatorSearch::Filters.from_params(sort: "followers_desc")
    result = Tiktok::CreatorSearch.new(shop: @shop, filters: filters).call
    assert_equal [ @high.id, @mid.id, @low.id ], result.pluck(:id)
  end

  test "total_count reflects filter without pagination" do
    filters = Tiktok::CreatorSearch::Filters.from_params(per_page: "1")
    search = Tiktok::CreatorSearch.new(shop: @shop, filters: filters)
    assert_equal 1, search.call.size
    assert_equal 3, search.total_count
  end

  test "skips TikTok API call when shop is not connected" do
    refute @shop.tiktok_connected?
    api_called = false
    stub_method(Tiktok::Resources::AffiliateCreator, :new, ->(*) { api_called = true; raise "should not be called" }) do
      Tiktok::CreatorSearch.new(shop: @shop, filters: Tiktok::CreatorSearch::Filters.from_params({})).call
    end
    refute api_called
  end
end
