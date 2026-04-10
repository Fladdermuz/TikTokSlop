class CreatorPolicy < ApplicationPolicy
  def index?  = shop_member?
  def show?   = shop_member?
  def export? = shop_member?
end
