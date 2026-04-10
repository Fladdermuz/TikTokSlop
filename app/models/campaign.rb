class Campaign < ApplicationRecord
  include ShopScoped

  STATUSES = %w[draft active paused ended].freeze

  has_many :invites, dependent: :destroy
  has_many :creators, through: :invites
  has_many :samples, through: :invites

  validates :name, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :commission_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1, allow_nil: true }

  scope :active, -> { where(status: "active") }

  def pending_invite_count
    invites.where(status: "pending").count
  end

  def sent_invite_count
    invites.where(status: "sent").count
  end
end
