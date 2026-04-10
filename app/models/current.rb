class Current < ActiveSupport::CurrentAttributes
  attribute :session, :shop, :membership
  delegate :user, to: :session, allow_nil: true

  def platform_admin?
    user&.platform_admin?
  end

  def shop_admin?
    membership&.admin?
  end

  def shop_member?
    membership&.member?
  end
end
