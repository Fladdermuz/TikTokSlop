require "test_helper"

class Tiktok::BulkInviteJobTest < ActiveJob::TestCase
  setup do
    @shop = shops(:alpha)
    Current.shop = @shop
    @product = Product.create!(name: "Serum", price_cents: 1000, status: "active")
    @campaign = Campaign.create!(name: "Spring", product: @product, commission_rate: 0.15, status: "active")
    @c1 = Creator.create!(external_id: "cr1", handle: "a")
    @c2 = Creator.create!(external_id: "cr2", handle: "b")
    Current.reset
  end

  teardown { Current.reset }

  test "creates invite records and enqueues send jobs" do
    assert_enqueued_jobs 2, only: Tiktok::SendInviteJob do
      Tiktok::BulkInviteJob.new.perform(@shop.id, @campaign.id, [ @c1.id, @c2.id ])
    end

    assert_equal 2, Invite.for_shop(@shop).where(campaign: @campaign).count
    assert Invite.for_shop(@shop).find_by(creator: @c1).pending?
  end

  test "skips creators already invited to this campaign" do
    Current.shop = @shop
    Invite.create!(creator: @c1, campaign: @campaign, status: "sent")
    Current.reset

    assert_enqueued_jobs 1, only: Tiktok::SendInviteJob do
      Tiktok::BulkInviteJob.new.perform(@shop.id, @campaign.id, [ @c1.id, @c2.id ])
    end
  end

  test "does nothing if campaign is not active" do
    @campaign.update!(status: "draft")
    assert_enqueued_jobs 0, only: Tiktok::SendInviteJob do
      Tiktok::BulkInviteJob.new.perform(@shop.id, @campaign.id, [ @c1.id ])
    end
  end
end
