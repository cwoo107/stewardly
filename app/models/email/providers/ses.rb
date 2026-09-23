# Amazon SES (v2 API) through the official SDK, sending raw MIME so our headers
# (List-Unsubscribe) go through as-is. Delivery, bounce, and complaint events arrive
# through an SNS topic subscribed to the webhook URL.
class Email::Providers::Ses < Email::DeliveryProvider
  def initialize(integration)
    @integration = integration
  end

  def deliver(message)
    response = client.send_email(
      from_email_address: message.from, destination: { to_addresses: [ message.to ] },
      content: { raw: { data: message.to_mail.to_s } },
      configuration_set_name: @integration.setting(:configuration_set),
      email_tags: [ { name: "stream", value: message.stream.to_s } ]
    )
    Result.new(message_id: response.message_id)
  rescue Aws::SESV2::Errors::ServiceError, Aws::Errors::MissingCredentialsError => error
    raise Error, error.message
  end

  # SNS signs every message; the SDK's MessageVerifier checks the signature and certificate.
  def verify_webhook!(request)
    raise InvalidWebhook, "Bad SNS signature" unless Aws::SNS::MessageVerifier.new.authentic?(request.raw_post)
  end

  # TODO(verify vendor docs): SNS envelope (Type, Message, SubscribeURL) and the SES event JSON
  # (eventType/notificationType, mail.messageId, bounce.bounceType, bounce.bouncedRecipients,
  # complaint.complainedRecipients, delivery.timestamp) are from memory of the AWS docs.
  # spec/models/email/providers/ses_spec.rb stays pending until they're checked.
  def events_from(webhook_event)
    envelope = webhook_event.payload
    return confirm_subscription(envelope) || [] if envelope["Type"] == "SubscriptionConfirmation"
    return [] unless envelope["Type"] == "Notification"

    notification = JSON.parse(envelope["Message"])
    message_id = notification.dig("mail", "messageId")
    case notification["eventType"] || notification["notificationType"]
    when "Delivery"
      Array(notification.dig("delivery", "recipients")).map { |email| Event.new("delivered", message_id, email, false, Time.zone.parse(notification.dig("delivery", "timestamp").to_s), nil) }
    when "Bounce"
      hard = notification.dig("bounce", "bounceType") == "Permanent"
      Array(notification.dig("bounce", "bouncedRecipients")).map { |r| Event.new("bounced", message_id, r["emailAddress"], hard, Time.zone.parse(notification.dig("bounce", "timestamp").to_s), r["diagnosticCode"]) }
    when "Complaint"
      Array(notification.dig("complaint", "complainedRecipients")).map { |r| Event.new("complained", message_id, r["emailAddress"], true, Time.zone.parse(notification.dig("complaint", "timestamp").to_s), nil) }
    else
      []
    end
  end

  private
    def client
      Aws::SESV2::Client.new(region: @integration.setting(:region) || "us-east-1",
        credentials: Aws::Credentials.new(@integration.credential(:access_key_id), @integration.credential(:secret_access_key)))
    end

    # SNS asks us to confirm a new subscription by visiting SubscribeURL. Only follow AWS's own SNS hosts.
    def confirm_subscription(envelope)
      uri = URI.parse(envelope["SubscribeURL"].to_s)
      return unless uri.is_a?(URI::HTTPS) && uri.host.to_s.match?(/\Asns\.[a-z0-9-]+\.amazonaws\.com\z/)

      Net::HTTP.get_response(uri)
      nil
    end
end
