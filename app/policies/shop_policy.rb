class ShopPolicy < ApplicationPolicy
  def index?  = user.present?
  def show?   = shop_member?
  def create? = user.present?  # any logged-in user can create their own shop
  def update? = shop_admin?
  def destroy? = shop_owner?
  def switch?  = shop_member?
end
