# An address the church must not email. Hard bounces and complaints block all mail
# (system email included); unsubscribes only stop campaigns, for all topics or one.
class Suppression < ApplicationRecord
  BLOCKS_ALL_MAIL = %w[ hard_bounce complaint ].freeze

  belongs_to :email_topic, optional: true
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  enum :reason, { unsubscribed: "unsubscribed", hard_bounce: "hard_bounce", complaint: "complaint", manual: "manual" }, validate: true

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :email, uniqueness: { scope: %i[ church_id email_topic_id ], message: "is already suppressed" }

  scope :recent_first, -> { order(created_at: :desc) }
  # Bounces, complaints, and manual additions that aren't limited to one topic.
  scope :blocking_all_mail, -> { where(reason: BLOCKS_ALL_MAIL).or(where(reason: "manual", email_topic_id: nil)) }

  # Suppressions that stop a campaign on this topic reaching someone.
  def self.for_campaigns(topic) = where(email_topic_id: nil).or(where(email_topic_id: topic))

  def self.blocks?(email, topic: nil)
    email = email.to_s.downcase
    blocking_all_mail.exists?(email:) || (topic != :system && for_campaigns(topic).exists?(email:))
  end

  def self.record!(email, reason:, topic: nil, source: nil)
    find_or_create_by!(email: email.to_s.strip.downcase, email_topic: topic) { |s| s.reason = reason; s.source = source }
  rescue ActiveRecord::RecordNotUnique
    find_by!(email: email.to_s.strip.downcase, email_topic: topic)
  end
end
