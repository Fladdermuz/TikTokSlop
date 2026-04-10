module ShopContext
  extend ActiveSupport::Concern

  included do
    before_action :resolve_current_shop
    helper_method :current_shop, :current_membership, :available_shops
  end

  private

  def resolve_current_shop
    return if Current.user.blank?

    shop = resolve_shop_from_param || resolve_shop_from_session || default_shop_for_current_user
    apply_current_shop(shop) if shop
  end

  def resolve_shop_from_param
    slug = params[:shop_slug] || params[:slug]
    return nil if slug.blank?
    Current.user.shops.find_by(slug: slug)
  end

  def resolve_shop_from_session
    id = session[:current_shop_id]
    return nil if id.blank?
    Current.user.shops.find_by(id: id)
  end

  def default_shop_for_current_user
    Current.user.shops.order(:created_at).first
  end

  def apply_current_shop(shop)
    Current.shop = shop
    Current.membership = Current.user.membership_for(shop)
    session[:current_shop_id] = shop.id
  end

  def current_shop
    Current.shop
  end

  def current_membership
    Current.membership
  end

  def available_shops
    Current.user&.shops&.order(:name).to_a || []
  end

  def require_shop_context!
    return if Current.shop
    redirect_to shops_path, alert: "Pick or create a shop to continue."
  end
end
