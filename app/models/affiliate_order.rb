class AffiliateOrder < ApplicationRecord
  include ShopScoped

  STATUSES = %w[pending confirmed cancelled refunded settled].freeze

  belongs_to :creator,  optional: true
  belongs_to :invite,   optional: true
  belongs_to :campaign, optional: true
  belongs_to :product,  optional: true

  validates :order_status, inclusion: { in: STATUSES }

  scope :in_window, ->(since) { where("ordered_at >= ?", since) }
  scope :by_date,   -> { order(ordered_at: :desc) }

  def gmv_dollars
    gmv_cents.to_f / 100
  end

  def commission_dollars
    commission_cents.to_f / 100
  end
end
