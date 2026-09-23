# A message a workflow wrote for one person, waiting for staff to approve (the approval
# queue). AI drafts land here unless a church admin turned on auto-send for that step.
class MessageDraft < ApplicationRecord
  belongs_to :workflow_step_execution
  belongs_to :person
  belongs_to :email_template, optional: true
  belongs_to :email_topic, optional: true
  belongs_to :ai_request, optional: true
  belongs_to :reviewed_by, class_name: "User", optional: true
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  enum :status, { pending: "pending", sent: "sent", rejected: "rejected" }, default: :pending, validate: true
  enum :source, { ai: "ai", staff: "staff" }, validate: true, prefix: true

  validates :subject, presence: true

  scope :oldest_first, -> { order(:created_at) }

  def workflow_run = workflow_step_execution.workflow_run

  # Sends it (optionally with staff edits). Returns the Delivery.
  def approve!(by: Current.user, subject: self.subject, body: self.body, auto: false)
    with_lock do
      raise ArgumentError, "This message was already #{status}" unless pending?
      raise ArgumentError, "Write the message before sending it" if body.blank?

      update!(subject:, body:, status: :sent, reviewed_by: by, reviewed_at: Time.current, auto_sent: auto)
    end
    Workflow::Mailing.new(workflow_step_execution, person:, template: email_template, topic: email_topic, subject:, body:).deliver!
  end

  def reject!(by: Current.user, note: nil)
    with_lock { update!(status: :rejected, reviewed_by: by, reviewed_at: Time.current, note:) if pending? }
  end
end
