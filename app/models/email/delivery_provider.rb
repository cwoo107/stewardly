# The interface every email provider adapter implements. The rest of the app only
# talks to this: deliver messages, check a webhook is genuine, and read its events.
class Email::DeliveryProvider
  class Error < StandardError; end
  class InvalidWebhook < StandardError; end

  Result = Data.define(:message_id)
  # type: delivered | bounced | complained | unsubscribed (opens and clicks are tracked ourselves)
  Event = Data.define(:type, :message_id, :email, :hard, :occurred_at, :detail)

  # The church's configured provider, or the platform's own delivery as the fallback.
  def self.for(church)
    church&.email_integration&.adapter || Email::Providers::Platform.new
  end

  def deliver(message) = raise(NotImplementedError)

  # Raises InvalidWebhook unless the request really came from the provider.
  def verify_webhook!(request) = raise(NotImplementedError)

  # Events in a stored WebhookEvent.
  def events_from(webhook_event) = raise(NotImplementedError)
end
