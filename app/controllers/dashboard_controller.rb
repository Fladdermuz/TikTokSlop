class DashboardController < ApplicationController
  def show
    if Current.shop.present?
      redirect_to shop_dashboard_path
    elsif Current.user&.shops&.any?
      redirect_to shops_path
    else
      redirect_to new_shop_path
    end
  end
end
