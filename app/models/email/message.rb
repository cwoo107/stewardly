# A provider-neutral email. stream: :broadcast (campaigns) or :transactional (system email).
Email::Message = Data.define(:to, :from, :from_name, :reply_to, :subject, :html, :text, :stream, :tag, :headers) do
  def self.text_from(html)
    Nokogiri::HTML(html).tap { |doc| doc.css("style, head, img").remove }.text.gsub(/[ \t]+/, " ").gsub(/\n\s*\n+/, "\n\n").strip
  end

  def from_header = from_name.present? ? %("#{from_name.delete('"')}" <#{from}>) : from

  # A Mail::Message, for providers that send raw MIME (SES) or through Action Mailer (platform).
  def to_mail
    message = self
    Mail.new do
      from message.from_header
      to message.to
      reply_to message.reply_to if message.reply_to.present?
      subject message.subject
      message.headers.to_h.each { |name, value| header[name] = value }
      text_part { body message.text; content_type "text/plain; charset=UTF-8" } if message.text.present?
      html_part { body message.html; content_type "text/html; charset=UTF-8" }
    end
  end
end
