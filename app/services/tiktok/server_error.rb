module Tiktok
  # 5xx — typically transient. Faraday's retry middleware handles most of these
  # before they reach us, so getting one here means we exhausted retries.
  class ServerError < Error; end
end
