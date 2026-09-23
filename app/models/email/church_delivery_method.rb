# Action Mailer delivery for church mail: through the current church's provider (or the
# platform), skipping addresses that hard-bounced or complained. System email ignores
# unsubscribes, which only apply to campaigns.
class Email::ChurchDeliveryMethod
  def initialize(settings = {})
    @settings = settings
  end

  attr_reader :settings

  def deliver!(mail)
    church = ActsAsTenant.current_tenant
    recipients = Array(mail.to).reject { |email| church && Suppression.blocking_all_mail.exists?(email: email.downcase) }
    return if recipients.empty?

    message = Email::Message.new(
      to: recipients.join(", "), from: Array(mail.from).first, from_name: mail[:from]&.display_names&.first,
      reply_to: Array(mail.reply_to).first, subject: mail.subject, stream: :transactional, tag: mail.header["X-Mailer-Action"]&.value,
      html: (mail.html_part || (mail.content_type.to_s.include?("html") ? mail : nil))&.decoded.to_s,
      text: (mail.text_part || (mail.content_type.to_s.include?("plain") ? mail : nil))&.decoded.to_s, headers: {})
    Email::DeliveryProvider.for(church).deliver(message)
  end
end
