module Ai
  Response = Data.define(:text, :model, :input_tokens, :output_tokens, :request_id, :raw) do
    def self.from_sdk(raw)
      block = Array(raw.content).first
      text =
        if block.nil?
          ""
        elsif block.respond_to?(:text)
          block.text
        elsif block.is_a?(Hash)
          block[:text] || block["text"] || ""
        else
          block.to_s
        end

      usage = raw.respond_to?(:usage) ? raw.usage : nil
      input_tokens  = usage&.respond_to?(:input_tokens)  ? usage.input_tokens  : 0
      output_tokens = usage&.respond_to?(:output_tokens) ? usage.output_tokens : 0

      model = raw.respond_to?(:model) ? raw.model.to_s : ""
      request_id = raw.respond_to?(:id) ? raw.id.to_s : nil

      new(
        text: text.to_s,
        model: model,
        input_tokens: input_tokens.to_i,
        output_tokens: output_tokens.to_i,
        request_id: request_id,
        raw: raw
      )
    end

    # Try to parse the text as JSON. Claude often wraps JSON in ```json fences.
    def json
      cleaned = text.to_s.strip
      cleaned = cleaned.gsub(/\A```(?:json)?\s*\n?/, "").gsub(/\n?```\s*\z/, "")
      JSON.parse(cleaned)
    end
  end
end
