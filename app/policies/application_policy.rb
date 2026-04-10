class ApplicationPolicy
  attr_reader :user, :membership, :shop, :record

  def initialize(user:, membership:, shop:, record: nil)
    @user, @membership, @shop, @record = user, membership, shop, record
  end

  # Catch-alls — override per resource as needed.
  def index?  = shop_member?
  def show?   = shop_member?
  def create? = shop_admin?
  def new?    = create?
  def update? = shop_admin?
  def edit?   = update?
  def destroy? = shop_admin?

  # Predicate helpers
  def platform_admin? = user&.platform_admin?
  def shop_admin?     = platform_admin? || membership&.admin?
  def shop_member?    = platform_admin? || membership&.member?
  def shop_owner?     = platform_admin? || membership&.owner?

  class NotAuthorizedError < StandardError
    attr_reader :policy, :action
    def initialize(policy:, action:)
      @policy, @action = policy, action
      super("Not authorized to #{action} on #{policy.class.name.sub(/Policy$/, '')}")
    end
  end
end
