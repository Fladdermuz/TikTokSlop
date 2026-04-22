class Shop < ApplicationRecord
  PLANS = %w[free pro].freeze
  STATUSES = %w[active suspended deleted].freeze

  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_one  :tiktok_token, dependent: :destroy
  has_many :products, dependent: :restrict_with_error
  has_many :campaigns, dependent: :destroy
  has_many :invites, dependent: :destroy
  has_many :samples, dependent: :destroy
  has_many :creator_videos,   dependent: :destroy
  has_many :affiliate_orders, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true,
                   format: { with: /\A[a-z0-9-]+\z/, message: "only lowercase letters, numbers, and dashes" }
  validates :plan, inclusion: { in: PLANS }
  validates :status, inclusion: { in: STATUSES }

  before_validation :generate_slug, on: :create

  scope :active, -> { where(status: "active") }

  def to_param
    slug
  end

  def tiktok_connected?
    tiktok_token.present?
  end

  def owners
    memberships.where(role: "owner").includes(:user).map(&:user)
  end

  private

  def generate_slug
    return if slug.present?
    base = name.to_s.parameterize
    candidate = base
    suffix = 1
    while Shop.exists?(slug: candidate)
      suffix += 1
      candidate = "#{base}-#{suffix}"
    end
    self.slug = candidate
  end
end
