# A post to one or more social accounts. Each account gets a SocialPostTarget, which is
# what actually publishes (once) and records the result.
class SocialPost < ApplicationRecord
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :event, optional: true
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  has_many :targets, class_name: "SocialPostTarget", dependent: :destroy, inverse_of: :social_post
  has_many :accounts, through: :targets, source: :social_account
  has_many_attached :media

  enum :status, { draft: "draft", scheduled: "scheduled", publishing: "publishing", published: "published",
    partly_failed: "partly_failed", failed: "failed", cancelled: "cancelled" }, default: :draft, validate: true
  enum :source, { staff: "staff", event_promo: "event_promo" }, validate: true, prefix: true

  validates :link_url, format: { with: %r{\Ahttps?://\S+\z}, message: "must be a web address" }, allow_blank: true
  validate :media_are_images

  scope :recent_first, -> { order(Arel.sql("COALESCE(published_at, scheduled_at, created_at) DESC")) }
  scope :needs_attention, -> { where(status: %w[ partly_failed failed ]).or(where(id: SocialPostTarget.where(status: "unknown").select(:social_post_id))) }

  def editable? = draft? || scheduled?
  def problems = Social::Validation.new(self).problems

  # Per-account caption overrides from the composer: { account_id => caption }.
  def captions_by_account=(captions)
    captions.to_h.each do |account_id, caption|
      targets.find { |target| target.social_account_id.to_s == account_id.to_s }&.caption = caption.to_s.strip.presence
    end
  end

  # Replaces the chosen accounts (only while editable).
  def account_ids=(ids)
    wanted = SocialAccount.usable.where(id: Array(ids).compact_blank).to_a
    self.targets = wanted.map { |account| targets.find { |target| target.social_account_id == account.id } || targets.build(social_account: account) }
  end

  def schedule!(at)
    raise ArgumentError, problems.to_sentence if problems.any?
    raise ArgumentError, "Choose a time in the future" unless at.future?

    transaction do
      update!(status: :scheduled, scheduled_at: at)
      targets.update_all(status: "pending", next_attempt_at: at, attempts: 0, error: nil)
    end
  end

  def publish_now! = schedule!(1.second.from_now).tap { SocialPublishSweepJob.perform_later }

  def cancel!
    transaction do
      update!(status: :cancelled)
      targets.where(status: "pending").update_all(status: "cancelled", next_attempt_at: nil)
    end
  end

  # The post's status follows its targets.
  def settle!
    statuses = targets.reload.map(&:status) - [ "cancelled" ]
    status =
      if statuses.empty? then self.status
      elsif statuses.all?("published") then "published"
      elsif statuses.any? { |s| s.in?(%w[ pending publishing ]) } then statuses.any? { |s| s.in?(%w[ publishing published ]) } ? "publishing" : "scheduled"
      elsif statuses.any? { |s| s.in?(%w[ published unknown ]) } then "partly_failed" # some went out, or might have: someone should look
      else "failed"
      end
    update!(status:, published_at: status == "published" ? (published_at || Time.current) : published_at)
  end

  private
    def media_are_images
      errors.add(:media, "must be photos (JPEG or PNG)") if media.any? { |file| !file.content_type.to_s.in?(%w[ image/jpeg image/png ]) }
    end
end
