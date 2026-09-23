# Postmark, through its official gem. Campaigns use the broadcast message stream and
# system email the transactional one (stream IDs are settings; Postmark's defaults below).
class Email::Providers::Postmark < Email::DeliveryProvider
  def initialize(integration)
    @integration = integration
  end

  def deliver(message)
    stream = message.stream == :broadcast ? (@integration.setting(:broadcast_stream) || "broadcast") : (@integration.setting(:transactional_stream) || "outbound")
    response = client.deliver(from: message.from_header, to: message.to, reply_to: message.reply_to, subject: message.subject,
      html_body: message.html, text_body: message.text, tag: message.tag, message_stream: stream,
      headers: message.headers.to_h.map { |name, value| { "Name" => name, "Value" => value } })
    Result.new(message_id: response[:message_id])
  rescue ::Postmark::Error => error
    raise Error, error.message
  end

  # Postmark webhooks are configured with HTTP basic auth credentials in the URL
  # (https://postmark:<webhook_password>@church.example/webhooks/<token>).
  # TODO(verify vendor docs): confirm basic auth is how Postmark authenticates webhooks for our setup.
  def verify_webhook!(request)
    expected = @integration.credential(:webhook_password)
    username, password = ActionController::HttpAuthentication::Basic.user_name_and_password(request) if request.authorization.present?
    valid = expected.present? && password.present? && ActiveSupport::SecurityUtils.secure_compare(password, expected) && username == "postmark"
    raise InvalidWebhook, "Bad webhook credentials" unless valid
  end

  # TODO(verify vendor docs): field names below (RecordType, MessageID, Recipient/Email, Type,
  # DeliveredAt/BouncedAt, SuppressSending) are from memory of Postmark's webhook payloads.
  # spec/models/email/providers/postmark_spec.rb stays pending until they're checked.
  def events_from(webhook_event)
    payload = webhook_event.payload
    email = payload["Recipient"] || payload["Email"]
    at = Time.zone.parse(payload["DeliveredAt"] || payload["BouncedAt"] || payload["ReceivedAt"] || payload["ChangedAt"] || Time.current.iso8601)

    event = case payload["RecordType"]
    when "Delivery" then [ "delivered", false ]
    when "Bounce" then [ "bounced", payload["Type"] == "HardBounce" ]
    when "SpamComplaint" then [ "complained", true ]
    when "SubscriptionChange" then payload["SuppressSending"] ? [ "unsubscribed", false ] : nil
    end
    return [] unless event

    [ Event.new(type: event.first, message_id: payload["MessageID"], email:, hard: event.last, occurred_at: at, detail: payload["Description"] || payload["Type"]) ]
  end

  private
    def client = ::Postmark::ApiClient.new(@integration.credential(:server_token))
end
