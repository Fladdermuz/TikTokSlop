# Shared wrapper around the Anthropic Ruby SDK.
#
# Every AI call in the app goes through this so we get:
# - consistent error handling
# - cost + token logging per shop (AiUsageLog)
# - per-shop rate limiting
# - sane defaults for model / max_tokens / system prompt
#
# Usage:
#
#   Ai::Client.new(shop: shop, feature: "moderation").complete(
#     system: "You are a moderation assistant...",
#     user:   "Please analyze: ...",
#     model:  :haiku,
#     max_tokens: 500
#   )
#   # => Ai::Response.new(text: "...", usage: {...}, raw: ...)
module Ai
  class Client
    # Approximate published pricing in cents per 1M tokens (2025 figures, update as needed).
    # Used for rough cost estimation only — real billing is on the Anthropic dashboard.
    PRICING = {
      "claude-haiku-4-5"  => { input: 100, output: 500 },   # $1.00 / $5.00 per 1M
      "claude-sonnet-4-6" => { input: 300, output: 1500 },  # $3.00 / $15.00 per 1M
      "claude-opus-4-6"   => { input: 1500, output: 7500 }  # $15.00 / $75.00 per 1M
    }.freeze

    MODEL_ALIASES = {
      haiku:  "claude-haiku-4-5",
      sonnet: "claude-sonnet-4-6",
      opus:   "claude-opus-4-6"
    }.freeze

    class Error < StandardError; end
    class RateLimitError < Error; end
    class AuthError < Error; end
    class ServerError < Error; end

    attr_reader :shop, :feature

    def initialize(shop:, feature: "other")
      @shop = shop
      @feature = feature
      @api_key = Rails.application.credentials.dig(:anthropic, :api_key)
      raise Error, "Anthropic API key not configured" if @api_key.blank?
    end

    # Perform a single-turn completion.
    #
    # @param system [String] system prompt
    # @param user   [String] user message content
    # @param model  [Symbol|String] :haiku | :sonnet | :opus or a literal model ID
    # @param max_tokens [Integer]
    # @param temperature [Float]
    # @return [Ai::Response]
    def complete(system:, user:, model: :haiku, max_tokens: 1024, temperature: 0.2)
      enforce_rate_limit!

      model_id = resolve_model(model)
      raw = anthropic_client.messages.create(
        model: model_id,
        system: system,
        max_tokens: max_tokens,
        temperature: temperature,
        messages: [ { role: "user", content: user } ]
      )

      response = Ai::Response.from_sdk(raw)
      record_usage(response)
      response
    rescue ::Anthropic::Errors::RateLimitError, ::Anthropic::RateLimitError => e
      raise RateLimitError, e.message
    rescue ::Anthropic::Errors::AuthenticationError, ::Anthropic::AuthenticationError => e
      raise AuthError, e.message
    rescue ::Anthropic::Errors::InternalServerError, ::Anthropic::InternalServerError => e
      raise ServerError, e.message
    rescue NameError
      # Older/newer SDK versions organize errors differently — rescue them generically.
      raise
    rescue => e
      # Any other SDK / network error — wrap so callers catch a single base class.
      raise Error, "#{e.class.name}: #{e.message}"
    end

    private

    def resolve_model(model)
      return model.to_s unless model.is_a?(Symbol)
      MODEL_ALIASES.fetch(model) { raise Error, "unknown model alias: #{model}" }
    end

    def enforce_rate_limit!
      limiter = Tiktok::RateLimiter.new(shop_id: @shop.id, bucket: :ai_calls, limit: 500, window: 3600)
      raise RateLimitError, "AI call budget exceeded for this shop (500/hr)" unless limiter.allow?
      limiter.record!
    end

    def record_usage(response)
      model_id = response.model.presence || resolve_model(:haiku)
      pricing  = PRICING[model_id] || PRICING[PRICING.keys.find { |k| model_id.start_with?(k) }] || { input: 0, output: 0 }
      cost = ((response.input_tokens * pricing[:input] + response.output_tokens * pricing[:output]) / 1_000_000.0).ceil

      AiUsageLog.cross_tenant.create!(
        shop: @shop,
        feature: @feature,
        model: model_id,
        input_tokens: response.input_tokens,
        output_tokens: response.output_tokens,
        cost_cents: cost,
        request_id: response.request_id
      )
    end

    def anthropic_client
      @anthropic_client ||= ::Anthropic::Client.new(api_key: @api_key)
    end
  end
end
