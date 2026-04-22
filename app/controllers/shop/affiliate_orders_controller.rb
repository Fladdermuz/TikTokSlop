class Shop::AffiliateOrdersController < Shop::BaseController
  def index
    authorize!(:index, AffiliateOrder)
    scope = Current.shop.affiliate_orders.includes(:creator, :campaign, :product).by_date
    scope = scope.where(creator_id: params[:creator_id]) if params[:creator_id].present?
    scope = scope.where(campaign_id: params[:campaign_id]) if params[:campaign_id].present?
    scope = scope.where(order_status: params[:status]) if params[:status].present?
    @orders = scope.limit(200)

    @totals = {
      count: @orders.size,
      gmv_cents:        @orders.sum(&:gmv_cents),
      commission_cents: @orders.sum(&:commission_cents)
    }
  end

  def show
    authorize!(:show, AffiliateOrder)
    @order = Current.shop.affiliate_orders.includes(:creator, :campaign, :product, :invite).find(params[:id])
  end
end
