# DNS guidance for sending from the church's own domain: SPF and DMARC are checked
# with a live lookup; DKIM values come from the provider's dashboard.
class Email::DomainCheck
  Record = Data.define(:kind, :name, :expected, :found, :ok)

  SPF_INCLUDES = { "postmark" => "include:spf.mtasv.net", "ses" => "include:amazonses.com" }.freeze

  def initialize(domain, provider:)
    @domain = domain
    @provider = provider
  end

  def records
    spf = txt(@domain).find { |value| value.start_with?("v=spf1") }
    dmarc = txt("_dmarc.#{@domain}").find { |value| value.start_with?("v=DMARC1") }
    include = SPF_INCLUDES[@provider]
    [
      Record.new("SPF", @domain, "v=spf1 #{include} ~all".squeeze(" "), spf, spf.present? && (include.nil? || spf.include?(include))),
      Record.new("DMARC", "_dmarc.#{@domain}", "v=DMARC1; p=none; rua=mailto:dmarc@#{@domain}", dmarc, dmarc.present?),
      Record.new("DKIM", "(from your provider)", "Add the DKIM records your #{Integration.label_for(@provider)} dashboard shows", nil, nil)
    ]
  end

  private
    def txt(name)
      Resolv::DNS.open do |dns|
        dns.timeouts = 2
        dns.getresources(name, Resolv::DNS::Resource::IN::TXT).map { |record| record.strings.join }
      end
    rescue Resolv::ResolvError, IOError, SystemCallError
      []
    end
end
