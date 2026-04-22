class CreatorVideoPolicy < ApplicationPolicy
  def index? = shop_member?
  def show?  = shop_member?
end
