require_relative "church_preview"

# Emails that don't go through Action Mailer: campaigns, workflow emails, and approved
# AI drafts are rendered per recipient by Delivery::Sending. These build the same
# message for the first person with an email address, without saving or sending anything.
class ChurchEmailPreview < ActionMailer::Preview
  include ChurchPreview

  # The most recent campaign as it went out (or the latest draft, compiled now).
  def campaign
    within_church do
      campaign = Campaign.where.not(html_snapshot: nil).order(:sent_at).last || Campaign.order(:created_at).last
      html = campaign.html_snapshot || EmailTemplate::Renderer.new(campaign.email_template).compile(tracking: Email::Tracking.new(church))
      preview_mail(Delivery.new(campaign:, person: recipient, email: recipient.email, church:, token: "preview", html_snapshot: html))
    end
  end

  # The first "Send an email" step in a workflow.
  def workflow_email
    within_church do
      step = Workflow.all.flat_map { |workflow| workflow.draft.all_steps }.find { |candidate| candidate["type"] == "send_email" && candidate.dig("config", "email_template_id") }
      template = EmailTemplate.find(step.dig("config", "email_template_id"))
      html = EmailTemplate::Renderer.new(template).compile(tracking: Email::Tracking.new(church))
      preview_mail(Delivery.new(person: recipient, email: recipient.email, church:, token: "preview", subject: step.dig("config", "subject"), html_snapshot: html))
    end
  end

  # A drafted message from the approval queue, as it would be sent.
  def ai_draft
    within_church do
      draft = MessageDraft.where.not(body: nil).order(:created_at).last
      template = Workflow::Mailing.with_body(draft.email_template, draft.body, church:)
      html = EmailTemplate::Renderer.new(template, church:).compile(tracking: Email::Tracking.new(church))
      preview_mail(Delivery.new(person: draft.person, email: draft.person.email || recipient.email, church:, token: "preview", subject: draft.subject, html_snapshot: html))
    end
  end

  private
    def recipient = Person.unmerged.where.not(email: nil).order(:id).first

    def preview_mail(delivery) = Delivery::Sending.new(delivery).message.to_mail
end
