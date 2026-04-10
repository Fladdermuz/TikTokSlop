# When TikTok rejects a message, this job asks Claude for a human-readable
# explanation of why, and stores it on the invite for the user to see.
#
# This is the key differentiator vs. Reacher: instead of a silent failure,
# the user sees "TikTok rejected this because the phrase 'earn commissions'
# implies income guarantees" plus a suggested rewrite.
class Moderation::AnalyzeFailureJob < ApplicationJob
  queue_as :default

  SYSTEM_PROMPT = <<~PROMPT.freeze
    You are a TikTok Shop content policy expert. A seller sent an affiliate
    outreach message to a creator via TikTok Shop's API, and it was rejected.

    Given the original message and TikTok's error response, explain:
    1. Why TikTok likely rejected this message (be specific about which
       phrases or claims triggered the rejection)
    2. What the seller should change to get the message approved
    3. A suggested rewrite that preserves the intent but avoids the issue

    Return JSON only:
    {
      "explanation": "<1-2 sentences on why it was rejected>",
      "problematic_phrases": ["<phrase1>", "<phrase2>"],
      "suggestion": "<what to change>",
      "rewrite": "<full rewritten message>"
    }
  PROMPT

  def perform(invite_id)
    invite = Invite.cross_tenant.find_by(id: invite_id)
    return unless invite&.failed?

    shop = invite.shop
    message = invite.message
    error = invite.error_message

    return if message.blank?

    client = Ai::Client.new(shop: shop, feature: "failure_analysis")
    response = client.complete(
      system: SYSTEM_PROMPT,
      user: "Original message:\n#{message}\n\nTikTok error: #{error}",
      model: :haiku,
      max_tokens: 500,
      temperature: 0.2
    )

    analysis = response.json
    invite.update!(raw: invite.raw.merge("failure_analysis" => analysis))

    Rails.logger.info("[failure analysis] invite=#{invite.id} explanation=#{analysis['explanation']&.truncate(100)}")
  rescue JSON::ParserError => e
    Rails.logger.warn("[failure analysis] JSON parse failed for invite=#{invite_id}: #{e.message}")
  rescue Ai::Client::Error => e
    Rails.logger.warn("[failure analysis] AI call failed for invite=#{invite_id}: #{e.message}")
  end
end
