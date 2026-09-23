# Matches hosts like grace.<app_domain>. Whether the church exists is decided
# by ChurchTenancy, which renders a 404 for unknown subdomains.
module ChurchSubdomain
  def self.matches?(request)
    request.subdomain.present? && Church::RESERVED_SUBDOMAINS.exclude?(request.subdomain)
  end
end
