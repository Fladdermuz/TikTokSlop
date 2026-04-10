class InvitePolicy < ApplicationPolicy
  def index?  = shop_member?
  def show?   = shop_member?
  def create? = shop_admin?
  def retry?  = shop_admin?
end
