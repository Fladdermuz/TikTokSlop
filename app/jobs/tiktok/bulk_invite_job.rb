# Fan-out job. Creates Invite records for each creator and enqueues per-invite
# SendInviteJobs spread over time to respect TikTok rate limits.
#
# Runs with no Current.shop — uses explicit shop_id everywhere.
class Tiktok::BulkInviteJob < ApplicationJob
  queue_as :tiktok

  DELAY_PER_INVITE = 2.seconds  # conservative; adjustable per-shop later

  def perform(shop_id, campaign_id, creator_ids)
    shop = Shop.find(shop_id)
    campaign = Campaign.for_shop(shop).find(campaign_id)

    unless campaign.active?
      Rails.logger.warn("[bulk invite] campaign #{campaign_id} is not active (status=#{campaign.status}); aborting")
      return
    end

    creator_ids.each_with_index do |creator_id, i|
      invite = create_invite(shop, campaign, creator_id)
      next unless invite

      Tiktok::SendInviteJob
        .set(wait: (i * DELAY_PER_INVITE))
        .perform_later(invite.id)
    end

    Rails.logger.info("[bulk invite] enqueued #{creator_ids.size} sends for campaign=#{campaign_id} shop=#{shop_id}")
  end

  private

  def create_invite(shop, campaign, creator_id)
    existing = Invite.cross_tenant.find_by(shop: shop, campaign: campaign, creator_id: creator_id)
    if existing
      Rails.logger.info("[bulk invite] skipping creator=#{creator_id}: already invited (status=#{existing.status})")
      return nil
    end
    Invite.cross_tenant.create!(shop: shop, campaign: campaign, creator_id: creator_id, status: "pending")
  rescue ActiveRecord::RecordInvalid => e
    # Unique constraint violation — creator already invited to this campaign.
    Rails.logger.info("[bulk invite] skipping creator=#{creator_id}: #{e.message}")
    nil
  end
end
