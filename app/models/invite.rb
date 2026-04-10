class Invite < ApplicationRecord
  STATUSES = %w[pending sending sent accepted declined expired failed].freeze

  belongs_to :creator
  belongs_to :campaign
  has_one :sample, dependent: :destroy

  validates :status, inclusion: { in: STATUSES }
  validates :creator_id, uniqueness: { scope: :campaign_id }

  scope :pending,  -> { where(status: "pending") }
  scope :sending,  -> { where(status: "sending") }
  scope :sent,     -> { where(status: "sent") }
  scope :accepted, -> { where(status: "accepted") }
  scope :failed,   -> { where(status: "failed") }

  def pending?; status == "pending"; end
  def sent?;    status == "sent";    end
  def failed?;  status == "failed";  end
end
