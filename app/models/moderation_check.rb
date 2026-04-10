class ModerationCheck < ApplicationRecord
  include ShopScoped

  RISKS = %w[low medium high blocked].freeze

  belongs_to :checkable, polymorphic: true

  validates :checked_text, presence: true
  validates :risk, inclusion: { in: RISKS }

  scope :latest_for, ->(checkable) {
    where(checkable_type: checkable.class.name, checkable_id: checkable.id)
      .order(created_at: :desc)
      .limit(1)
  }

  def blocked?;  risk == "blocked"; end
  def high?;     risk == "high";    end
  def passable?; %w[low medium].include?(risk); end
end
