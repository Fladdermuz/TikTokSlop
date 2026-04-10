require "test_helper"

class SampleTest < ActiveSupport::TestCase
  setup do
    @shop = shops(:alpha)
    Current.shop = @shop
    @product = Product.create!(name: "Serum", price_cents: 1000, status: "active")
    @campaign = Campaign.create!(name: "Spring", product: @product, commission_rate: 0.15, sample_offer: true)
    @creator = Creator.create!(external_id: "cr_sample", handle: "sampler")
    @invite = Invite.create!(creator: @creator, campaign: @campaign, status: "sent")
    @sample = Sample.create!(invite: @invite, status: "requested")
  end

  teardown { Current.reset }

  test "record_spark_code transitions to spark_code_received" do
    @sample.update!(status: "delivered")
    @sample.record_spark_code!("SPARK123ABC")
    assert_equal "spark_code_received", @sample.status
    assert_equal "SPARK123ABC", @sample.spark_code
    assert @sample.spark_code_received_at.present?
  end

  test "on_delivery schedules follow-up 5 days out" do
    @sample.update!(status: "delivered", delivered_at: Time.current)
    @sample.on_delivery!
    assert @sample.next_follow_up_at.present?
    assert @sample.next_follow_up_at > 4.days.from_now
  end

  test "record_follow_up_sent increments count and schedules next" do
    @sample.update!(status: "delivered")
    @sample.record_follow_up_sent!("Hey! Got the spark code?")
    assert_equal "follow_up_sent", @sample.status
    assert_equal 1, @sample.follow_up_count
    assert_equal "Hey! Got the spark code?", @sample.last_follow_up_message
    assert @sample.next_follow_up_at > 2.days.from_now
  end

  test "followable? returns false after max follow-ups reached" do
    @sample.update!(status: "follow_up_sent", follow_up_count: 3, max_follow_ups: 3)
    refute @sample.followable?
  end

  test "needs_follow_up scope finds samples due for follow-up" do
    @sample.update!(status: "delivered", next_follow_up_at: 1.hour.ago)
    assert_includes Sample.needs_follow_up, @sample

    @sample.update!(next_follow_up_at: 1.day.from_now)
    refute_includes Sample.needs_follow_up, @sample
  end

  test "auto-creates sample when invite transitions to accepted with sample_offer" do
    creator2 = Creator.create!(external_id: "cr_auto", handle: "autosample")
    invite2 = Invite.create!(creator: creator2, campaign: @campaign, status: "sent")
    assert_nil invite2.sample
    invite2.update!(status: "accepted")
    invite2.reload
    assert invite2.sample.present?
    assert_equal "requested", invite2.sample.status
  end

  test "does not auto-create sample if campaign has no sample_offer" do
    @campaign.update!(sample_offer: false)
    invite2 = Invite.create!(creator: Creator.create!(external_id: "cr2", handle: "b"), campaign: @campaign, status: "sent")
    invite2.update!(status: "accepted")
    invite2.reload
    assert_nil invite2.sample
  end
end
