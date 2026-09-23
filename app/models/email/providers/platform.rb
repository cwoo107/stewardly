# The platform's own delivery (SMTP in production, letter_opener in development, the
# test deliveries array in tests). Used when a church hasn't connected a provider.
class Email::Providers::Platform < Email::DeliveryProvider
  def deliver(message)
    mail = message.to_mail
    method = Rails.configuration.x.platform_delivery_method
    mail.delivery_method(ActionMailer::Base.delivery_methods.fetch(method), ActionMailer::Base.public_send("#{method}_settings"))
    mail.deliver
    Result.new(message_id: mail.message_id)
  rescue Net::SMTPError, IOError, SystemCallError => error
    raise Error, error.message
  end

  def verify_webhook!(_request) = raise(InvalidWebhook, "The platform provider has no webhooks")
  def events_from(_webhook_event) = []
end
