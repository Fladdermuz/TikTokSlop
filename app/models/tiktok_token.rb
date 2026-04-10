class TiktokToken < ApplicationRecord
  encrypts :access_token
  encrypts :refresh_token

  validates :shop_id, presence: true, uniqueness: true
  validates :access_token, :refresh_token, :access_expires_at, :refresh_expires_at, presence: true

  scope :active, -> { where("access_expires_at > ?", Time.current) }

  def self.current
    order(updated_at: :desc).first
  end

  def access_expired?(buffer: 5.minutes)
    access_expires_at <= Time.current + buffer
  end

  def refresh_expired?
    refresh_expires_at <= Time.current
  end
end
