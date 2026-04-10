module ShopScoped
  extend ActiveSupport::Concern

  included do
    belongs_to :shop

    # Tenant isolation: every query is automatically filtered to Current.shop.
    # Use `unscoped` (or .for_shop) for explicit cross-tenant access (platform admin / jobs).
    default_scope -> { where(shop_id: Current.shop.id) if Current.shop }

    validates :shop, presence: true

    before_validation :assign_current_shop, on: :create
  end

  class_methods do
    # Explicit cross-tenant scope. Always preferred over `unscoped` for readability.
    def for_shop(shop)
      unscoped.where(shop_id: shop.id)
    end

    # Bypass the default scope entirely. Use only in jobs/admin where Current.shop is unset.
    def cross_tenant
      unscoped
    end
  end

  private

  def assign_current_shop
    self.shop ||= Current.shop
  end
end
