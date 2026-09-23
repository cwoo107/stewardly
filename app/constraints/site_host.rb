# Church websites: grace.<sites_domain> or a verified custom domain. Checked before the
# admin app's routes, since grace.sites.localhost also looks like a church subdomain.
module SiteHost
  def self.matches?(request) = site_host_name?(request.host) && Site.for_host(request.host).present?

  # Cheap check first: the sites domain, or a host that isn't one of the app's own.
  def self.site_host_name?(host)
    host = host.to_s.downcase
    app_domain = Rails.configuration.x.app_domain
    return true if host.end_with?(".#{Rails.configuration.x.sites_domain}")

    host != app_domain && !host.end_with?(".#{app_domain}")
  end
end
