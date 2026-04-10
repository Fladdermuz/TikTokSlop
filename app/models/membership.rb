class Membership < ApplicationRecord
  ROLES = %w[owner admin member].freeze

  belongs_to :user
  belongs_to :shop

  validates :role, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :shop_id }

  scope :owners,  -> { where(role: "owner") }
  scope :admins,  -> { where(role: %w[owner admin]) }
  scope :members, -> { where(role: %w[owner admin member]) }
  scope :accepted, -> { where.not(joined_at: nil) }
  scope :pending,  -> { where(joined_at: nil) }

  def owner?  = role == "owner"
  def admin?  = role.in?(%w[owner admin])
  def member? = role.in?(%w[owner admin member])
  def pending? = joined_at.nil?
end
