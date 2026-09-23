# One post going to one account. Publishes at most once: see Social::Publishing.
#   pending → publishing → published | failed (after retries) | unknown (the call's outcome
#   wasn't recorded; never retried automatically, so a post can't be duplicated)
class SocialPostTarget < ApplicationRecord
  MAX_ATTEMPTS = 3
  BACKOFF = [ 5.minutes, 30.minutes, 2.hours ].freeze

  belongs_to :social_post, inverse_of: :targets
  belongs_to :social_account
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  enum :status, { pending: "pending", publishing: "publishing", published: "published", failed: "failed",
    unknown: "unknown", cancelled: "cancelled" }, default: :pending, validate: true

  scope :due, ->(now = Time.current) { pending.where(next_attempt_at: ..now).joins(:social_post).where(social_posts: { status: %w[ scheduled publishing ] }) }

  def caption_text = caption.presence || social_post.body

  # Staff checked the network: it did go out (with an optional link), or try again.
  def mark_posted!(permalink: nil)
    update!(status: :published, permalink: permalink.presence || self.permalink, published_at: published_at || Time.current, error: nil)
    social_post.settle!
  end

  def retry!
    update!(status: :pending, next_attempt_at: Time.current, error: nil, attempts: [ attempts, MAX_ATTEMPTS - 1 ].min)
    social_post.update!(status: :scheduled) unless social_post.publishing?
    SocialPublishSweepJob.perform_later
  end
end
