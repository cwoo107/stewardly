# Sends one delivery (a campaign's, or a workflow email's): only if it's still queued
# (locked, so a retried job can't send twice), re-checking suppressions, personalising
# the saved HTML, and logging a touchpoint.
#
# One gap remains: if the provider accepts the email and the process dies before we
# save that, a retry could send it again. Providers don't offer idempotency keys for this.
class Delivery::Sending
  def initialize(delivery)
    @delivery = delivery
    @campaign = delivery.campaign
    @church = delivery.church
  end

  def send!
    return unless claim!

    if Suppression.blocks?(@delivery.email, topic: @delivery.topic)
      return @delivery.update!(status: :skipped, error: "Suppressed before sending")
    end

    result = provider.deliver(message)
    @delivery.update!(status: :sent, sent_at: Time.current, provider_message_id: result.message_id, error: nil)
    log_touchpoint
  rescue Email::DeliveryProvider::Error => error
    @delivery.update!(status: :failed, error: error.message.first(500))
  end

  # The email as this recipient gets it (personalized HTML, text, unsubscribe headers).
  # Public for the development mail previews.
  def message
    links = @delivery.links
    html = EmailTemplate::Renderer.personalize(@delivery.html_snapshot || @campaign.html_snapshot, person: @delivery.person, links:)
    subject = EmailTemplate::Renderer.personalize(@delivery.subject.presence || @campaign.subject, person: @delivery.person, links:)

    Email::Message.new(
      to: @delivery.email, from: @church.email_from_address, from_name: @campaign&.from_name.presence || @church.name,
      reply_to: @campaign&.reply_to.presence || @church.contact_email, subject:, html:,
      text: Email::Message.text_from(html), stream: :broadcast, tag: @campaign ? "campaign-#{@campaign.id}" : "workflow",
      headers: { "List-Unsubscribe" => "<#{links.unsubscribe}>", "List-Unsubscribe-Post" => "List-Unsubscribe=One-Click" })
  end

  private
    def claim!
      @delivery.with_lock do
        next false unless @delivery.queued?

        @delivery.update!(status: :sending)
      end
    end

    def provider = @provider ||= Email::DeliveryProvider.for(@church)

    def log_touchpoint
      if @campaign
        @delivery.person.touchpoints.create!(kind: :email, subject: @campaign, summary: "Email: #{@campaign.name}".first(200), occurred_at: Time.current)
      else
        workflow = @delivery.workflow_step_execution&.workflow_run&.workflow
        @delivery.person.touchpoints.create!(kind: :workflow_message, subject: workflow,
          summary: "Workflow email: #{@delivery.subject}".first(200), occurred_at: Time.current)
      end
    end
end
