class Campaign < ApplicationRecord
  include ShopScoped

  STATUSES = %w[draft active paused ended].freeze
  TRANSITIONS = {
    "draft"  => %w[active],
    "active" => %w[paused ended],
    "paused" => %w[active ended],
    "ended"  => [] # terminal
  }.freeze

  belongs_to :product
  has_many :invites, dependent: :destroy
  has_many :creators, through: :invites
  has_many :samples, through: :invites

  validates :name, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :commission_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1, allow_nil: true }

  scope :active,  -> { where(status: "active") }
  scope :visible, -> { where.not(status: "ended") }

  def draft?;  status == "draft";  end
  def active?; status == "active"; end
  def paused?; status == "paused"; end
  def ended?;  status == "ended";  end

  def can_transition_to?(new_status)
    TRANSITIONS.fetch(status, []).include?(new_status.to_s)
  end

  def transition_to!(new_status)
    unless can_transition_to?(new_status)
      errors.add(:status, "cannot transition from #{status} to #{new_status}")
      return false
    end
    update(status: new_status)
  end

  # Editable fields depend on lifecycle state.
  def editable_fields
    case status
    when "draft"  then %w[name product_id commission_rate sample_offer message_template notes]
    when "active" then %w[message_template notes]  # send-time template edits only
    when "paused" then %w[message_template notes]
    when "ended"  then []  # read-only
    else []
    end
  end

  def pending_invite_count
    invites.where(status: "pending").count
  end

  def sent_invite_count
    invites.where(status: "sent").count
  end

  def accepted_invite_count
    invites.where(status: "accepted").count
  end
end
