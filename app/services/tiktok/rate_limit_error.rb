module Tiktok
  # 429 or business code 12004001. Caller should back off using rate limit headers.
  class RateLimitError < Error
    attr_reader :retry_after
    def initialize(message = nil, retry_after: nil, **kwargs)
      @retry_after = retry_after
      super(message, **kwargs)
    end
  end
end
