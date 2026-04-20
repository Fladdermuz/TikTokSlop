class Campaign < ApplicationRecord
  include ShopScoped

  STATUSES = %w[draft active paused ended].freeze
  MODES = %w[target open].freeze
  TRANSITIONS = {
    "draft"  => %w[active],
    "active" => %w[paused ended],
    "paused" => %w[active ended],
    "ended"  => [] # terminal
  }.freeze

  belongs_to :product
  has_many :invites, dependent: :destroy
  has_many :creators, through: :invites
  has_many :samples, through: :invites

  validates :name, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :mode, inclusion: { in: MODES }
  validates :commission_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1, allow_nil: true }

  def target_mode? = mode == "target"
  def open_mode?   = mode == "open"

  # Pick a commission rate for a new invite. When A/B testing is enabled,
  # return commission_rate_b for ~cohort_b_split_pct of creators; otherwise
  # return the primary commission_rate. The cohort assignment is returned
  # alongside so it can be recorded on the invite.
  def assign_commission
    if ab_test_enabled? && commission_rate_b.present? && rand(100) < cohort_b_split_pct
      [commission_rate_b, "B"]
    else
      [commission_rate, "A"]
    end
  end

  # When an active campaign's commission rate or message template changes,
  # propagate the update to every live target collaboration on TikTok.
  after_update :push_collab_updates_on_change, if: :active?

  TRACKED_UPDATE_FIELDS = %w[commission_rate message_template].freeze
  TRACKED_SAMPLE_RULE_FIELDS = %w[max_samples_per_creator sample_valid_days sample_min_follower_threshold].freeze

  # When an open-mode campaign's sample rules change, push them to TikTok.
  after_update :push_sample_rule_updates, if: -> { open_mode? && external_id.present? }

  scope :active,  -> { where(status: "active") }
  scope :visible, -> { where.not(status: "ended") }

  def draft?;  status == "draft";  end
  def active?; status == "active"; end
  def paused?; status == "paused"; end
  def ended?;  status == "ended";  end

  def can_transition_to?(new_status)
    TRANSITIONS.fetch(status, []).include?(new_status.to_s)
  end

  def transition_to!(new_status)
    unless can_transition_to?(new_status)
      errors.add(:status, "cannot transition from #{status} to #{new_status}")
      return false
    end

    prior_status = status
    result = update(status: new_status)
    return result unless result

    case [prior_status, new_status.to_s]
    when %w[draft active]
      # Open-mode campaigns create a single Open Collaboration on TikTok at
      # activation time; target-mode campaigns defer collab creation until
      # individual invites are sent.
      Tiktok::CreateOpenCollabJob.perform_later(id) if open_mode?
    when %w[active paused], %w[paused ended], %w[active ended]
      if open_mode?
        Tiktok::RemoveOpenCollabJob.perform_later(id)
      else
        Tiktok::CancelCampaignCollabsJob.perform_later(id)
      end
    when %w[paused active]
      if open_mode?
        Tiktok::CreateOpenCollabJob.perform_later(id)
      else
        Tiktok::RecreateCampaignCollabsJob.perform_later(id)
      end
    end

    result
  end

  # Editable fields depend on lifecycle state.
  def editable_fields
    case status
    when "draft"  then %w[name product_id commission_rate sample_offer message_template follow_up_template personalize_per_creator notes mode max_samples_per_creator sample_valid_days sample_min_follower_threshold ab_test_enabled commission_rate_b cohort_b_split_pct]
    when "active" then %w[message_template follow_up_template notes max_samples_per_creator sample_valid_days sample_min_follower_threshold]
    when "paused" then %w[message_template follow_up_template notes max_samples_per_creator sample_valid_days sample_min_follower_threshold]
    when "ended"  then []
    else []
    end
  end

  def pending_invite_count
    invites.where(status: "pending").count
  end

  private

  def push_collab_updates_on_change
    return unless (saved_changes.keys & TRACKED_UPDATE_FIELDS).any?
    Tiktok::UpdateCampaignCollabsJob.perform_later(id)
  end

  def push_sample_rule_updates
    return unless (saved_changes.keys & TRACKED_SAMPLE_RULE_FIELDS).any?
    Tiktok::UpdateSampleRulesJob.perform_later(id)
  end

  public

  def sent_invite_count
    invites.where(status: "sent").count
  end

  def accepted_invite_count
    invites.where(status: "accepted").count
  end
end
