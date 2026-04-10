module Tiktok
  # Base error for everything raised by the TikTok client.
  class Error < StandardError
    attr_reader :code, :request_id, :http_status, :body

    def initialize(message = nil, code: nil, request_id: nil, http_status: nil, body: nil)
      @code = code
      @request_id = request_id
      @http_status = http_status
      @body = body
      super(message || default_message)
    end

    private

    def default_message
      parts = [self.class.name.split("::").last]
      parts << "code=#{code}" if code
      parts << "http=#{http_status}" if http_status
      parts << "request_id=#{request_id}" if request_id
      parts.join(" ")
    end
  end
end
