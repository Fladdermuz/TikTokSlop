class Product < ApplicationRecord
  include ShopScoped

  STATUSES = %w[active inactive].freeze

  has_one  :knowledge, class_name: "ProductKnowledge", dependent: :destroy
  has_many :campaigns, dependent: :restrict_with_error

  validates :name, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :external_id, uniqueness: { scope: :shop_id, allow_nil: true }
  validates :price_cents, numericality: { greater_than_or_equal_to: 0 }

  scope :active, -> { where(status: "active") }

  def price_dollars
    price_cents.to_f / 100
  end

  def display_label
    price_cents > 0 ? "#{name} — $#{format('%.2f', price_dollars)}" : name
  end
end
