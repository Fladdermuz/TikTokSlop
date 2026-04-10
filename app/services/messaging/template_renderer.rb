# Safe-ish mustache-style variable substitution for campaign message templates.
#
# Whitelisted variables only. Anything not in the whitelist either renders as
# an empty string (lenient mode) or raises (strict mode).
#
# Usage:
#   Messaging::TemplateRenderer.render(
#     "Hey {{creator.handle}}! Love your {{creator.category}} content. We'd love to send you {{product.name}}.",
#     creator:  creator,
#     campaign: campaign,
#     shop:     shop,
#     product:  product
#   )
#
# Syntax: `{{ namespace.key }}` with optional whitespace inside the braces.
# Variable names are case-sensitive and limited to `[a-z_]+\.[a-z_]+`.
module Messaging
  class TemplateRenderer
    ALLOWED_VARIABLES = {
      "creator.handle"          => ->(ctx) { ctx[:creator]&.handle },
      "creator.display_name"    => ->(ctx) { ctx[:creator]&.display_name || ctx[:creator]&.handle },
      "creator.country"         => ->(ctx) { ctx[:creator]&.country },
      "creator.top_category"    => ->(ctx) { Array(ctx[:creator]&.categories).first },
      "campaign.name"           => ->(ctx) { ctx[:campaign]&.name },
      "campaign.commission_pct" => ->(ctx) { ctx[:campaign]&.commission_rate ? "#{(ctx[:campaign].commission_rate * 100).round(1)}%" : nil },
      "shop.name"               => ->(ctx) { ctx[:shop]&.name },
      "product.name"            => ->(ctx) { ctx[:product]&.name }
    }.freeze

    VARIABLE_PATTERN = /\{\{\s*([a-z_]+\.[a-z_]+)\s*\}\}/

    class UnknownVariableError < StandardError; end

    def self.render(template, strict: false, **context)
      new(template: template, context: context, strict: strict).render
    end

    # Return the list of variable keys found in a template (for editor hints).
    def self.variables_in(template)
      template.to_s.scan(VARIABLE_PATTERN).flatten.uniq
    end

    # Return the list of unknown variables in a template (for validation).
    def self.unknown_variables_in(template)
      variables_in(template).reject { |v| ALLOWED_VARIABLES.key?(v) }
    end

    def self.allowed_keys
      ALLOWED_VARIABLES.keys
    end

    def initialize(template:, context:, strict: false)
      @template = template.to_s
      @context = context
      @strict = strict
    end

    def render
      @template.gsub(VARIABLE_PATTERN) do
        key = Regexp.last_match(1)
        resolver = ALLOWED_VARIABLES[key]
        if resolver.nil?
          raise UnknownVariableError, "Unknown template variable: #{key}" if @strict
          ""
        else
          resolver.call(@context).to_s
        end
      end
    end
  end
end
