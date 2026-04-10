module Authorization
  extend ActiveSupport::Concern

  included do
    rescue_from ApplicationPolicy::NotAuthorizedError, with: :user_not_authorized
  end

  private

  def authorize!(action, record_or_class)
    policy = policy_for(record_or_class)
    unless policy.public_send("#{action}?")
      raise ApplicationPolicy::NotAuthorizedError.new(policy: policy, action: action)
    end
    true
  end

  def policy_for(record_or_class)
    klass = if record_or_class.is_a?(Class)
              "#{record_or_class.name}Policy".constantize
            else
              "#{record_or_class.class.name}Policy".constantize
            end
    record = record_or_class.is_a?(Class) ? nil : record_or_class
    klass.new(
      user:       Current.user,
      membership: Current.membership,
      shop:       Current.shop,
      record:     record
    )
  end

  def user_not_authorized(exception)
    Rails.logger.warn("Unauthorized: #{exception.message} (user=#{Current.user&.id} shop=#{Current.shop&.id})")
    redirect_back fallback_location: root_path, alert: "You don't have permission to do that."
  end
end
