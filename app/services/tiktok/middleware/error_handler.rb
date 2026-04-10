# Maps TikTok Shop API responses to typed Tiktok::* exceptions.
#
# TikTok responses always have shape:
#   { code: <int>, message: <string>, request_id: <string>, data: { ... } }
#
# code == 0 means success regardless of HTTP status. Any non-zero code is an error,
# even if HTTP status is 200. We map the most common business codes to typed errors;
# everything else falls through as a generic Tiktok::Error.
module Tiktok
  module Middleware
    class ErrorHandler < Faraday::Middleware
      # Business error codes from TikTok docs (extend as encountered)
      AUTH_CODES        = [ 36004004, 36004003, 35004004, 36004008 ].freeze  # token invalid/expired/cipher mismatch
      RATE_LIMIT_CODES  = [ 12004001 ].freeze
      NOT_FOUND_CODES   = [ 36003003 ].freeze
      VALIDATION_RANGE  = 36000000..36999999  # validation/business range; refined per error

      def on_complete(env)
        body = env.body
        return raise_for_http_status(env) unless body.is_a?(Hash)

        code = body["code"].to_i
        return if code.zero?

        message    = body["message"].to_s
        request_id = body["request_id"]
        http_status = env.status

        attrs = { code: code, request_id: request_id, http_status: http_status, body: body }

        case
        when AUTH_CODES.include?(code)
          raise Tiktok::AuthError.new(message, **attrs)
        when RATE_LIMIT_CODES.include?(code) || http_status == 429
          retry_after = env.response_headers["Retry-After"]&.to_i ||
                        env.response_headers["X-Rate-Limit-Reset"]&.to_i
          raise Tiktok::RateLimitError.new(message, retry_after: retry_after, **attrs)
        when NOT_FOUND_CODES.include?(code) || http_status == 404
          raise Tiktok::NotFoundError.new(message, **attrs)
        when http_status >= 500
          raise Tiktok::ServerError.new(message, **attrs)
        else
          raise Tiktok::ValidationError.new(message, **attrs)
        end
      end

      private

      def raise_for_http_status(env)
        return if env.status.between?(200, 299)

        attrs = { http_status: env.status, body: env.body }
        case env.status
        when 401, 403 then raise Tiktok::AuthError.new("HTTP #{env.status}", **attrs)
        when 404      then raise Tiktok::NotFoundError.new("HTTP #{env.status}", **attrs)
        when 429      then raise Tiktok::RateLimitError.new("HTTP 429", **attrs)
        when 500..599 then raise Tiktok::ServerError.new("HTTP #{env.status}", **attrs)
        else               raise Tiktok::Error.new("HTTP #{env.status}", **attrs)
        end
      end
    end
  end
end
