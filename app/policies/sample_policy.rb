class SamplePolicy < ApplicationPolicy
  def index?        = shop_member?
  def show?         = shop_member?
  def create?       = shop_admin?
  def update?       = shop_admin?
  def record_spark_code? = shop_member?
end
