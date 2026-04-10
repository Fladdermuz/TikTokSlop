class Invite < ApplicationRecord
  include ShopScoped

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

  def pending?;  status == "pending";  end
  def sent?;     status == "sent";    end
  def accepted?; status == "accepted"; end
  def failed?;   status == "failed";  end

  after_update :auto_create_sample_on_acceptance

  private

  def auto_create_sample_on_acceptance
    return unless saved_change_to_status? && status == "accepted"
    return unless campaign.sample_offer?
    return if sample.present?

    create_sample!(
      shop: shop,
      status: "requested"
    )
  end
end
