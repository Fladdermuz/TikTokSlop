class RoiPolicy < ApplicationPolicy
  def show? = shop_member?
end
