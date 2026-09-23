# An email to a segment, sent in batches. The compiled HTML is saved at send time
# (html_snapshot), so editing the template later never changes what went out.
class Campaign < ApplicationRecord
  belongs_to :email_template, optional: true
  belongs_to :segment, optional: true
  belongs_to :email_topic, optional: true
  belongs_to :created_by, class_name: "User", optional: true
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  has_many :deliveries, dependent: :delete_all
  has_many :extra_recipients, class_name: "CampaignExtraRecipient", dependent: :delete_all

  enum :status, { draft: "draft", scheduled: "scheduled", sending: "sending", sent: "sent", cancelled: "cancelled" }, default: :draft, validate: true

  validates :name, presence: true
  validates :reply_to, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  scope :recent_first, -> { order(Arel.sql("COALESCE(sent_at, scheduled_at, created_at) DESC")) }
  scope :due, ->(now = Time.current) { scheduled.where(scheduled_at: ..now) }

  def editable? = draft? || scheduled?

  # What stops this campaign sending (empty when it's ready).
  def problems
    [
      ("Choose a template" unless email_template),
      ("Choose an audience" unless segment),
      ("Choose a topic" unless email_topic),
      ("Add a subject" if subject.blank?),
      ("Add the church's postal address in email settings (the law requires it)" if church.mailing_address.blank?),
      ("Connect an email provider in email settings" unless church.email_integration || Rails.configuration.x.platform_campaigns)
    ].compact
  end

  def ready? = problems.empty?

  def audience = Campaign::Audience.new(self)

  def schedule!(at)
    raise ArgumentError, problems.to_sentence unless ready?

    update!(status: :scheduled, scheduled_at: at)
  end

  def send_now! = schedule!(Time.current).tap { CampaignDispatchJob.perform_later(self) }

  def cancel!
    update!(status: :cancelled) if scheduled?
  end

  # Six headline numbers, from the deliveries.
  def stats
    counts = deliveries.group(:status).count
    sent = counts.except("queued", "sending", "failed", "skipped").values.sum
    {
      recipients: deliveries.count, sent:,
      delivered: counts["delivered"].to_i + deliveries.where(status: %w[ bounced complained ]).where.not(delivered_at: nil).count,
      bounced: counts["bounced"].to_i, complained: counts["complained"].to_i, failed: counts["failed"].to_i,
      opened: deliveries.where.not(first_opened_at: nil).count, clicked: deliveries.where.not(first_clicked_at: nil).count,
      unsubscribed: deliveries.where.not(unsubscribed_at: nil).count
    }
  end
end
