class MembershipPolicy < ApplicationPolicy
  def index?   = shop_member?
  def create?  = shop_admin?
  def update?  = shop_admin?
  def destroy? = shop_admin?
end
