class CreatorVideo < ApplicationRecord
  include ShopScoped

  belongs_to :creator,  optional: true
  belongs_to :product,  optional: true
  belongs_to :campaign, optional: true
  belongs_to :invite,   optional: true

  scope :recent, -> { order(posted_at: :desc) }

  def attributed_gmv_dollars
    attributed_gmv_cents.to_f / 100
  end

  def engagement_rate
    return 0.0 if views.to_i.zero?
    ((likes + comments + shares).to_f / views).round(4)
  end
end
