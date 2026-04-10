# Receives incoming webhook events from TikTok Shop.
#
# TikTok calls POST /tiktok/webhooks with a JSON body signed using HMAC-SHA256.
# This endpoint is intentionally unauthenticated (no user session required) but
# MUST verify the TikTok signature before processing any payload.
#
# Signature verification:
#   TikTok sends a `Webhook-Signature` header (or `x-tts-signature` depending on
#   the API version). The signature is HMAC-SHA256(app_secret, raw_body) encoded
#   as a lowercase hex string. We compare using a constant-time comparison to
#   prevent timing attacks.
#
# Supported event types (routed via `type` field in payload):
#   - ORDER_STATUS_CHANGED
#   - COLLABORATION_STATUS_CHANGED
#   - SAMPLE_STATUS_CHANGED
#   - PRODUCT_STATUS_CHANGED
#
# Unknown event types are logged and acknowledged with 200 OK — TikTok will
# retry on non-2xx responses, so we only return a non-200 for signature failures.
class Tiktok::WebhooksController < ApplicationController
  allow_unauthenticated_access

  # Disable CSRF for this endpoint; TikTok cannot send a CSRF token.
  skip_before_action :verify_authenticity_token

  def receive
    raw_body = request.body.read

    unless valid_signature?(raw_body)
      Rails.logger.warn("[tiktok webhook] rejected event — invalid signature")
      head :unauthorized
      return
    end

    payload = parse_payload(raw_body)
    if payload.nil?
      Rails.logger.warn("[tiktok webhook] rejected event — unparseable JSON body")
      head :bad_request
      return
    end

    event_type = payload["type"]
    Rails.logger.info("[tiktok webhook] received event type=#{event_type}")

    route_event(event_type, payload)

    head :ok
  end

  private

  # Verify the HMAC-SHA256 signature sent by TikTok.
  # TikTok sends the signature as a lowercase hex digest of HMAC-SHA256(app_secret, raw_body).
  def valid_signature?(raw_body)
    received = request.headers["Webhook-Signature"].presence ||
               request.headers["x-tts-signature"].presence

    return false if received.blank?

    expected = OpenSSL::HMAC.hexdigest("sha256", Tiktok::Client.app_secret, raw_body)
    ActiveSupport::SecurityUtils.secure_compare(expected, received)
  end

  def parse_payload(raw_body)
    JSON.parse(raw_body)
  rescue JSON::ParserError
    nil
  end

  def route_event(event_type, payload)
    case event_type
    when "ORDER_STATUS_CHANGED"
      handle_order_status_changed(payload)
    when "COLLABORATION_STATUS_CHANGED"
      handle_collaboration_status_changed(payload)
    when "SAMPLE_STATUS_CHANGED"
      handle_sample_status_changed(payload)
    when "PRODUCT_STATUS_CHANGED"
      handle_product_status_changed(payload)
    else
      Rails.logger.info("[tiktok webhook] unhandled event type=#{event_type}, skipping")
    end
  end

  # ── Event handlers ───────────────────────────────────────────────────────────

  def handle_order_status_changed(payload)
    data = payload["data"] || {}
    Rails.logger.info("[tiktok webhook] order status changed order_id=#{data["order_id"]} status=#{data["status"]}")
    # TODO: enqueue a job to sync the order record, e.g.:
    # Tiktok::SyncOrderStatusJob.perform_later(data["order_id"])
  end

  def handle_collaboration_status_changed(payload)
    data = payload["data"] || {}
    Rails.logger.info("[tiktok webhook] collaboration status changed collaboration_id=#{data["collaboration_id"]} status=#{data["status"]}")
    # TODO: enqueue a job to sync the invite/collaboration status:
    # invite = Invite.find_by(tiktok_collaboration_id: data["collaboration_id"])
    # Tiktok::SyncInviteStatusJob.perform_later(invite.id) if invite
  end

  def handle_sample_status_changed(payload)
    data = payload["data"] || {}
    Rails.logger.info("[tiktok webhook] sample status changed sample_id=#{data["sample_id"]} status=#{data["status"]}")
    # TODO: enqueue a job to sync the sample status:
    # Tiktok::SyncSampleStatusJob.perform_later(data["sample_id"])
  end

  def handle_product_status_changed(payload)
    data = payload["data"] || {}
    Rails.logger.info("[tiktok webhook] product status changed product_id=#{data["product_id"]} status=#{data["status"]}")
    # TODO: enqueue a job to sync the product record:
    # Tiktok::SyncProductsJob.perform_later
  end
end
