# Applies a stored webhook's events: delivery status, and suppressions for hard
# bounces and complaints. Safe to replay: updates are idempotent and suppressions unique.
class Email::EventProcessing
  def initialize(webhook_event)
    @webhook_event = webhook_event
  end

  def process!
    events = @webhook_event.integration.adapter.events_from(@webhook_event)
    Delivery.transaction do
      events.each { |event| apply(event) }
      @webhook_event.update!(status: :processed, processed_at: Time.current, error: nil)
    end
    events
  rescue JSON::ParserError, KeyError, ArgumentError => error
    @webhook_event.update!(status: :failed, error: "#{error.class}: #{error.message}")
    []
  end

  private
    def apply(event)
      delivery = event.message_id.present? && Delivery.find_by(provider_message_id: event.message_id)

      case event.type
      when "delivered"
        delivery&.update!(status: :delivered, delivered_at: delivery.delivered_at || event.occurred_at) if delivery&.sent?
      when "bounced"
        delivery&.update!(status: :bounced, error: event.detail)
        Suppression.record!(event.email, reason: :hard_bounce, source: "bounce") if event.hard && event.email.present?
      when "complained"
        delivery&.update!(status: :complained)
        Suppression.record!(event.email, reason: :complaint, source: "complaint") if event.email.present?
      when "unsubscribed"
        delivery ? delivery.unsubscribe!(all_topics: true) : Suppression.record!(event.email, reason: :unsubscribed, source: "provider")
      end
    end
end
