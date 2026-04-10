class Sample < ApplicationRecord
  include ShopScoped

  STATUSES = %w[requested approved rejected shipped delivered returned].freeze

  belongs_to :invite
  has_one :creator,  through: :invite
  has_one :campaign, through: :invite

  validates :status, inclusion: { in: STATUSES }

  scope :open,      -> { where(status: %w[requested approved shipped]) }
  scope :delivered, -> { where(status: "delivered") }
end
