# One email to one person: a campaign recipient (unique per campaign and person) or a
# workflow email (unique per workflow step execution). Sent at most once.
class Delivery < ApplicationRecord
  belongs_to :campaign, optional: true
  belongs_to :workflow_step_execution, optional: true
  belongs_to :email_topic, optional: true
  belongs_to :person
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  has_secure_token :token

  validate :has_a_source

  def topic = campaign ? campaign.email_topic : email_topic

  enum :status, { queued: "queued", sending: "sending", sent: "sent", delivered: "delivered", bounced: "bounced",
    complained: "complained", failed: "failed", skipped: "skipped" }, default: :queued, validate: true

  def record_open!
    self.class.where(id:).update_all([ "open_count = open_count + 1, first_opened_at = COALESCE(first_opened_at, ?)", Time.current ])
  end

  def record_click!
    self.class.where(id:).update_all([ "click_count = click_count + 1, first_clicked_at = COALESCE(first_clicked_at, ?)", Time.current ])
  end

  # Unsubscribe from this campaign's topic, or from every topic.
  def unsubscribe!(all_topics: false)
    transaction do
      Suppression.record!(email, reason: :unsubscribed, topic: all_topics ? nil : topic,
        source: campaign_id ? "campaign #{campaign_id}" : "workflow email")
      update!(unsubscribed_at: unsubscribed_at || Time.current)
    end
  end

  def links
    host = Email::Tracking.base_url(church)
    Email::Drops::Links.new(unsubscribe: "#{host}/u/#{token}",
      preferences: "#{host}/email_preferences/#{person.generate_token_for(:email_preferences)}", token:)
  end

  private
    def has_a_source
      errors.add(:base, "needs a campaign or a workflow step") unless campaign_id || workflow_step_execution_id
    end
end
