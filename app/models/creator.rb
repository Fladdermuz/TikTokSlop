class Creator < ApplicationRecord
  GMV_TIERS = %w[under_10k 10k_100k 100k_500k 500k_plus].freeze

  has_many :invites, dependent: :destroy
  has_many :campaigns, through: :invites

  validates :external_id, presence: true, uniqueness: true
  validates :gmv_tier, inclusion: { in: GMV_TIERS, allow_nil: true }

  scope :min_gmv, ->(cents) { where("gmv_cents >= ?", cents) }
  scope :max_gmv, ->(cents) { where("gmv_cents <= ?", cents) }
  scope :followers_between, ->(min, max) { where(follower_count: min..max) }
  scope :in_category, ->(cat) { where("? = ANY(categories)", cat) }
  scope :in_country, ->(country) { where(country: country) }
  scope :not_yet_invited_to, ->(campaign) {
    where.not(id: Invite.where(campaign: campaign).select(:creator_id))
  }

  def gmv_dollars
    gmv_cents.to_f / 100
  end
end
