class ShopsController < ApplicationController
  before_action :set_shop, only: :switch

  def index
    @shops = Current.user.shops.order(:name)
  end

  def new
    @shop = Shop.new
  end

  def create
    @shop = Shop.new(shop_params)
    Shop.transaction do
      @shop.save!
      Membership.create!(user: Current.user, shop: @shop, role: "owner", joined_at: Time.current)
    end
    session[:current_shop_id] = @shop.id
    redirect_to shop_dashboard_path, notice: "Shop created."
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  def switch
    unless Current.user.member_of?(@shop)
      redirect_to shops_path, alert: "You don't have access to that shop." and return
    end
    session[:current_shop_id] = @shop.id
    redirect_to shop_dashboard_path, notice: "Switched to #{@shop.name}."
  end

  private

  def set_shop
    @shop = Shop.find(params[:id])
  end

  def shop_params
    params.expect(shop: %i[name timezone])
  end
end
