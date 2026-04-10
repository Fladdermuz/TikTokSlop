class TiktokTokenPolicy < ApplicationPolicy
  def show?    = shop_member?
  def create?  = shop_admin?
  def destroy? = shop_admin?
end
