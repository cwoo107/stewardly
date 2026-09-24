# Development-only demo mode (bin/demo): Cloudflare quick tunnels give two random public
# addresses, which this maps to one church. DEMO_APP_HOST serves the church's admin app and
# member area; DEMO_SITE_HOST serves its public website. Links, redirects, and emails use those
# https addresses. Off unless DEMO_CHURCH is set, and never in production or tests.
module DemoTunnel
  def self.enabled? = Rails.env.development? && ENV["DEMO_CHURCH"].present?
  def self.app_host = (ENV["DEMO_APP_HOST"].presence if enabled?)
  def self.site_host = (ENV["DEMO_SITE_HOST"].presence if enabled?)
  def self.tunnel_host?(host) = enabled? && [ app_host, site_host ].compact.include?(host.to_s.downcase)

  def self.church = (ActsAsTenant.without_tenant { Church.find_by(subdomain: ENV["DEMO_CHURCH"]) } if enabled?)
  def self.demo_church?(church) = enabled? && church&.subdomain == ENV["DEMO_CHURCH"]

  def self.church_for_host(host) = (church if app_host.present? && host.to_s.downcase == app_host)
  def self.site_for_host(host) = (church&.then { |c| ActsAsTenant.without_tenant { Site.find_by(church: c) } } if site_host.present? && host.to_s.downcase == site_host)

  def self.app_host_for(church) = (app_host if demo_church?(church))
  def self.site_host_for(church) = (site_host if demo_church?(church))
end
