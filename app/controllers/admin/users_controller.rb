class Admin::UsersController < Admin::BaseController
  def index
    @users = User.order(created_at: :desc).includes(:memberships)
  end

  def show
    @user = User.find(params[:id])
    @memberships = @user.memberships.includes(:shop)
  end
end
