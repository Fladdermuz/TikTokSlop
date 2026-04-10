class AiUsageLog < ApplicationRecord
  include ShopScoped

  FEATURES = %w[moderation crafter_template crafter_personalized failure_analysis other].freeze

  validates :feature, inclusion: { in: FEATURES }
  validates :model, presence: true

  scope :in_range, ->(from, to) { where(created_at: from..to) }
  scope :for_feature, ->(feature) { where(feature: feature) }

  def self.total_cost_cents_for(shop:, since: 30.days.ago)
    for_shop(shop).where("created_at >= ?", since).sum(:cost_cents)
  end
end
