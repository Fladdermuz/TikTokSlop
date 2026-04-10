require "test_helper"

class Tiktok::SendInviteJobTest < ActiveJob::TestCase
  setup do
    @shop = shops(:alpha)
    Current.shop = @shop
    @product = Product.create!(name: "Serum", price_cents: 1000, status: "active", external_id: "sku_1")
    @campaign = Campaign.create!(name: "Spring", product: @product, commission_rate: 0.15, status: "active",
                                  message_template: "Hey {{creator.handle}}! Try {{product.name}}.")
    @creator = Creator.create!(external_id: "cr_test", handle: "tester")
    @invite = Invite.create!(creator: @creator, campaign: @campaign, status: "pending")

    @token = TiktokToken.create!(
      shop: @shop, external_shop_id: "tt1", shop_cipher: "cipher_1",
      access_token: "at", refresh_token: "rt",
      access_expires_at: 7.days.from_now, refresh_expires_at: 30.days.from_now
    )
    Current.reset

    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown { Current.reset }

  test "sends invite through the full pipeline on success" do
    fake_collab = Object.new
    fake_collab.define_singleton_method(:create_targeted) { |**_| "ext_collab_123" }

    stub_method(Tiktok::Resources::AffiliateCollaboration, :new, ->(**_) { fake_collab }) do
      stub_method(Moderation::AiScanner, :scan, ->(_, **_) { Moderation::Result.empty }) do
        Tiktok::SendInviteJob.new.perform(@invite.id)
      end
    end

    @invite.reload
    assert_equal "sent", @invite.status
    assert_equal "ext_collab_123", @invite.external_id
    assert @invite.sent_at.present?
    assert_includes @invite.message, "Hey tester! Try Serum."
  end

  test "blocks send when moderation returns blocked" do
    @campaign.update!(message_template: "Guaranteed payout of $1000/day! WhatsApp me!")

    stub_method(Moderation::AiScanner, :scan, ->(_, **_) { Moderation::Result.empty }) do
      Tiktok::SendInviteJob.new.perform(@invite.id)
    end

    @invite.reload
    assert_equal "failed", @invite.status
    assert_match(/moderation/i, @invite.error_message)
  end

  test "fails gracefully when no TikTok token exists" do
    @token.destroy!
    Tiktok::SendInviteJob.new.perform(@invite.id)
    @invite.reload
    assert_equal "failed", @invite.status
    assert_match(/no tiktok connection/i, @invite.error_message)
  end

  test "enqueues failure analysis on ValidationError" do
    fake_collab = Object.new
    fake_collab.define_singleton_method(:create_targeted) { |**_| raise Tiktok::ValidationError.new("content rejected", code: 36001001) }

    assert_enqueued_jobs 1, only: Moderation::AnalyzeFailureJob do
      stub_method(Tiktok::Resources::AffiliateCollaboration, :new, ->(**_) { fake_collab }) do
        stub_method(Moderation::AiScanner, :scan, ->(_, **_) { Moderation::Result.empty }) do
          Tiktok::SendInviteJob.new.perform(@invite.id)
        end
      end
    end

    @invite.reload
    assert_equal "failed", @invite.status
    assert_match(/content rejected/i, @invite.error_message)
  end
end
