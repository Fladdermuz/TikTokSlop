class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :shops, through: :memberships

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true,
                            format: { with: URI::MailTo::EMAIL_REGEXP }

  scope :platform_admins, -> { where(platform_admin: true) }

  def platform_admin?
    platform_admin == true
  end

  def membership_for(shop)
    memberships.find_by(shop_id: shop&.id)
  end

  def member_of?(shop)
    memberships.exists?(shop_id: shop&.id)
  end

  def display_name
    name.presence || email_address
  end
end
