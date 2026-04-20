# Send a single invite to TikTok. The pipeline:
#
#  1. Render message (template substitution or personalized AI)
#  2. Moderation scan — block if risk is "blocked"
#  3. Check rate limit — reschedule if exhausted
#  4. Call TikTok API
#  5. Update invite status
#  6. On failure: enqueue failure analysis job
#
# Idempotent: skips if the invite has already progressed past "pending".
class Tiktok::SendInviteJob < ApplicationJob
  queue_as :tiktok
  retry_on Tiktok::RateLimitError, wait: :polynomially_longer, attempts: 5
  discard_on ActiveRecord::RecordNotFound

  MAX_RETRIES = 3

  def perform(invite_id)
    invite = Invite.cross_tenant.find(invite_id)
    return unless invite.status.in?(%w[pending sending])

    shop = invite.shop
    campaign = invite.campaign
    creator = invite.creator
    token = TiktokToken.cross_tenant.find_by(shop: shop)

    unless token
      fail_invite(invite, "No TikTok connection for this shop")
      return
    end

    # 1. Render the message
    message = render_message(campaign, creator, shop)

    # 2. Moderation gate
    moderation = Moderation::Scanner.scan_and_persist(message, shop: shop, checkable: invite, use_ai: true)
    if moderation.blocked?
      fail_invite(invite, "Blocked by moderation: #{moderation.issues.first&.dig(:reason) || 'content policy violation'}")
      return
    end

    # 3. Rate limit check
    limiter = Tiktok::RateLimiter.new(shop_id: shop.id, bucket: :invites)
    unless limiter.allow?
      raise Tiktok::RateLimitError.new("Per-shop invite rate limit exceeded")
    end

    # 3b. Sample eligibility pre-check
    send_sample = campaign.sample_offer?
    if send_sample && shop.tiktok_connected?
      sample_client = Tiktok::Resources::AffiliateSample.new(token: token, shop_cipher: token.shop_cipher)
      unless sample_client.sample_eligible?(creator_id: creator.external_id, product_id: campaign.product.external_id)
        Rails.logger.warn("[send invite] Creator #{creator.external_id} not eligible for sample on product #{campaign.product.external_id} — sending invite without sample offer")
        send_sample = false
      end
    end

    # 4. Pick commission rate (honoring A/B test split if enabled)
    commission_rate, cohort = campaign.assign_commission

    # 5. Send via TikTok API
    invite.update!(status: "sending", message: message)
    collab = Tiktok::Resources::AffiliateCollaboration.new(token: token, shop_cipher: token.shop_cipher)
    external_id = collab.create_targeted(
      creator_id:      creator.external_id,
      product_id:      campaign.product.external_id,
      commission_rate: commission_rate,
      message:         message,
      sample_offer:    send_sample
    )

    # 6. Success
    invite.update!(
      status: "sent",
      external_id: external_id,
      sent_at: Time.current,
      raw: invite.raw.merge("cohort" => cohort, "commission_rate_sent" => commission_rate)
    )
    limiter.record!

  rescue Tiktok::AuthError => e
    fail_invite(invite, "TikTok auth error: #{e.message}", enqueue_analysis: false)
    Tiktok::RefreshTokenJob.perform_later(token&.id) if token
  rescue Tiktok::RateLimitError
    invite.update!(status: "pending") if invite.status == "sending"
    raise # let retry_on handle it
  rescue Tiktok::ValidationError => e
    fail_invite(invite, "TikTok rejected: #{e.message} (code=#{e.code})", enqueue_analysis: true)
  rescue Tiktok::Error => e
    handle_generic_error(invite, e)
  end

  private

  def render_message(campaign, creator, shop)
    if campaign.personalize_per_creator? && campaign.product.knowledge&.populated?
      result = Messaging::Crafter.personalized_for(campaign: campaign, creator: creator, shop: shop)
      result.text
    elsif campaign.message_template.present?
      Messaging::TemplateRenderer.render(
        campaign.message_template,
        creator: creator,
        campaign: campaign,
        shop: shop,
        product: campaign.product
      )
    else
      "Hi @#{creator.handle}! We'd love to partner with you on #{campaign.product.name} via #{shop.name}."
    end
  end

  def fail_invite(invite, reason, enqueue_analysis: false)
    invite.update!(
      status: "failed",
      error_message: reason,
      retry_count: invite.retry_count + 1
    )
    if enqueue_analysis
      Moderation::AnalyzeFailureJob.perform_later(invite.id)
    end
  end

  def handle_generic_error(invite, error)
    Rails.logger.error("[send invite] #{error.class.name}: #{error.message} invite=#{invite.id} request_id=#{error.request_id}")
    if invite.retry_count < MAX_RETRIES
      invite.update!(retry_count: invite.retry_count + 1, status: "pending")
      self.class.set(wait: (invite.retry_count * 30).seconds).perform_later(invite.id)
    else
      fail_invite(invite, "Exhausted retries: #{error.message}")
    end
  end
end
