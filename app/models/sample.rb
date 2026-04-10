class Sample < ApplicationRecord
  include ShopScoped

  STATUSES = %w[requested approved rejected shipped delivered follow_up_sent spark_code_received no_response returned].freeze
  TERMINAL = %w[spark_code_received no_response rejected returned].freeze
  FOLLOWABLE = %w[delivered follow_up_sent].freeze

  DEFAULT_FOLLOW_UP_TEMPLATE = <<~MSG.freeze
    Hey {{creator.handle}}! Hope you're loving the {{product.name}} 🙌

    If you've had a chance to create content with it, we'd love to boost your video as a Spark Ad! Could you share the Spark Ads authorization code?

    Here's how to generate it:
    1. Open TikTok → tap your profile
    2. Go to Creator tools → TikTok Shop
    3. Find the video → Spark Ads → Generate code
    4. Copy and send it back here!

    The code helps us run your video as a paid ad, which means more views for your content too. Thanks!
  MSG

  belongs_to :invite
  has_one :creator,  through: :invite
  has_one :campaign, through: :invite

  validates :status, inclusion: { in: STATUSES }

  scope :open,             -> { where(status: %w[requested approved shipped]) }
  scope :delivered,        -> { where(status: "delivered") }
  scope :needs_follow_up,  -> { where(status: FOLLOWABLE).where("next_follow_up_at <= ? AND follow_up_count < max_follow_ups", Time.current) }
  scope :with_spark_code,  -> { where(status: "spark_code_received") }

  def terminal? = TERMINAL.include?(status)
  def followable? = FOLLOWABLE.include?(status) && follow_up_count < max_follow_ups

  def record_spark_code!(code)
    update!(
      spark_code: code,
      spark_code_received_at: Time.current,
      status: "spark_code_received"
    )
  end

  def mark_no_response!
    update!(status: "no_response")
  end

  def schedule_follow_up!(days_from_now: 5)
    update!(next_follow_up_at: days_from_now.days.from_now)
  end

  def record_follow_up_sent!(message)
    update!(
      status: "follow_up_sent",
      follow_up_count: follow_up_count + 1,
      last_follow_up_message: message,
      next_follow_up_at: 3.days.from_now  # next follow-up in 3 more days
    )
  end

  # When status changes to "delivered", auto-schedule the first follow-up.
  def on_delivery!
    schedule_follow_up!(days_from_now: 5) unless terminal?
  end

  def follow_up_template
    campaign&.follow_up_template.presence || DEFAULT_FOLLOW_UP_TEMPLATE
  end
end
