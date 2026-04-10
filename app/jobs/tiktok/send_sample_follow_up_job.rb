# Sends a Spark Code follow-up message to a creator whose sample has been
# delivered. Uses the campaign's follow_up_template (or the default).
#
# Flow:
#   1. Render follow-up message with template variables
#   2. Moderation scan (same pipeline as invites)
#   3. Send via TikTok messaging API
#   4. Update sample: status → follow_up_sent, increment count, schedule next
#   5. If follow_up_count >= max_follow_ups and still no spark code → mark no_response
class Tiktok::SendSampleFollowUpJob < ApplicationJob
  queue_as :tiktok

  def perform(sample_id)
    sample = Sample.cross_tenant.find_by(id: sample_id)
    return unless sample&.followable?

    shop = sample.shop
    invite = sample.invite
    creator = invite.creator
    campaign = invite.campaign
    product = campaign.product

    token = TiktokToken.cross_tenant.find_by(shop: shop)
    unless token
      Rails.logger.warn("[follow-up] no TikTok connection for shop=#{shop.id}")
      return
    end

    # 1. Render follow-up message
    template = sample.follow_up_template
    message = Messaging::TemplateRenderer.render(
      template,
      creator: creator,
      campaign: campaign,
      shop: shop,
      product: product
    )

    # 2. Moderation
    moderation = Moderation::Scanner.scan(message, shop: shop, use_ai: false)
    if moderation.blocked?
      Rails.logger.warn("[follow-up] message blocked by moderation for sample=#{sample.id}")
      return
    end

    # 3. Send via TikTok (same collab messaging channel)
    limiter = Tiktok::RateLimiter.new(shop_id: shop.id, bucket: :invites)
    unless limiter.allow?
      self.class.set(wait: 5.minutes).perform_later(sample_id)
      return
    end

    # Send follow-up via TikTok IM messaging (seller.affiliate_messages.write scope).
    begin
      messaging = Tiktok::Resources::Message.new(token: token, shop_cipher: token.shop_cipher)
      conversation_id = messaging.create_conversation(creator_id: creator.external_id)
      messaging.send_message(conversation_id: conversation_id, content: message)
      limiter.record!
    rescue Tiktok::Error => e
      Rails.logger.warn("[follow-up] TikTok error for sample=#{sample.id}: #{e.message}")
      # Don't fail hard — schedule retry
      sample.update!(next_follow_up_at: 1.day.from_now)
      return
    end

    # 4. Update sample
    sample.record_follow_up_sent!(message)

    # 5. If we've exhausted follow-ups, give up
    if sample.follow_up_count >= sample.max_follow_ups
      Rails.logger.info("[follow-up] exhausted #{sample.max_follow_ups} follow-ups for sample=#{sample.id}")
      # Keep in follow_up_sent — user can manually mark no_response or enter spark code
    end

    Rails.logger.info("[follow-up] sent follow-up ##{sample.follow_up_count} for sample=#{sample.id}")
  end
end
