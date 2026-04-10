class Admin::ShopsController < Admin::BaseController
  def index
    @shops = Shop.order(created_at: :desc).includes(:memberships)
  end

  def show
    @shop = Shop.find(params[:id])
    @memberships = @shop.memberships.includes(:user)
    @token = TiktokToken.cross_tenant.find_by(shop: @shop)
    @invite_count = Invite.for_shop(@shop).count
    @sample_count = Sample.for_shop(@shop).count
  end
end
