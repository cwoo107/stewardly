# Does a domain point at us? A CNAME to the sites target, or (for bare domains, which
# can't have a CNAME) A records that are all ours.
class Site::DnsCheck
  Result = Data.define(:ok, :message)

  def initialize(hostname, resolver: nil)
    @hostname = hostname
    @resolver = resolver
  end

  def call
    target = Rails.configuration.x.sites_cname_target
    cnames = lookup(Resolv::DNS::Resource::IN::CNAME).map { |record| record.name.to_s.downcase.delete_suffix(".") }
    return Result.new(true, "CNAME points to #{target}") if cnames.include?(target)
    return Result.new(false, "The CNAME points to #{cnames.first}, not #{target}") if cnames.any?

    ips = Rails.configuration.x.sites_apex_ips
    addresses = lookup(Resolv::DNS::Resource::IN::A).map { |record| record.address.to_s }
    return Result.new(true, "A records point to Stewardly") if ips.any? && addresses.any? && (addresses - ips).empty?
    return Result.new(false, "The A records point to #{addresses.to_sentence}, not Stewardly") if addresses.any?

    Result.new(false, "No DNS records found yet. Changes can take a few hours.")
  end

  private
    def lookup(type)
      with_resolver { |dns| dns.getresources(@hostname, type) }
    rescue Resolv::ResolvError, IOError, SystemCallError
      []
    end

    def with_resolver
      return yield(@resolver) if @resolver

      Resolv::DNS.open do |dns|
        dns.timeouts = 3
        yield dns
      end
    end
end
