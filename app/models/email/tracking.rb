# Click and open tracking for a campaign. Links are rewritten to signed redirects
# (so the redirect can't be abused to point anywhere else) and a 1×1 pixel is added.
# {{ links.token }} is filled in per recipient.
class Email::Tracking
  def self.verifier
    @verifier ||= ActiveSupport::MessageVerifier.new(Rails.application.key_generator.generate_key("email links"), url_safe: true)
  end

  def self.sign(url) = verifier.generate(url)
  def self.target_for(signed) = verifier.verified(signed.to_s)

  # Where links in email point: https in production, the dev server's port in development.
  def self.base_url(church)
    return "https://#{church.host}" if Rails.env.production? || DemoTunnel.app_host_for(church)

    "http://#{church.host}#{":#{Rails.configuration.x.dev_port}" if Rails.configuration.x.dev_port.presence}"
  end

  def initialize(church)
    @base = self.class.base_url(church)
  end

  def apply(html)
    html = html.gsub(EmailTemplate::Renderer::TRACKABLE_LINK) do
      url = Regexp.last_match(1)
      %(href="#{@base}/t/c/{{ links.token }}/#{self.class.sign(CGI.unescapeHTML(url))}")
    end
    html.sub("</body>", %(<img src="#{@base}/t/o/{{ links.token }}.gif" width="1" height="1" alt="" style="display:none" /></body>))
  end
end
