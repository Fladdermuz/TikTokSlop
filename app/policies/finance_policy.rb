class FinancePolicy < ApplicationPolicy
  def show?         = shop_member?
  def index?        = shop_member?
  def payments?     = shop_member?
  def statements?   = shop_member?
  def transactions? = shop_member?
end
