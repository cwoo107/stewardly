# A church's public website: a theme, its settings, and pages. Served on
# <subdomain>.<sites_domain> and on verified custom domains.
class Site < ApplicationRecord
  acts_as_tenant :church

  has_many :pages, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :site
  has_many :domains, class_name: "SiteDomain", dependent: :destroy

  validates :name, presence: true
  validates :theme_key, inclusion: { in: ->(_) { Site::Theme.keys } }

  # The site a request host belongs to, or nil. Looked up without a tenant (the host decides it).
  def self.for_host(host)
    host = host.to_s.downcase.delete_suffix(".")
    demo = DemoTunnel.site_for_host(host) and return demo
    sites_domain = Rails.configuration.x.sites_domain
    ActsAsTenant.without_tenant do
      if host.end_with?(".#{sites_domain}")
        subdomain = host.delete_suffix(".#{sites_domain}")
        church = Church.find_by(subdomain:) unless subdomain.include?(".")
        church && Site.find_by(church:)
      else
        SiteDomain.verified.find_by(hostname: host)&.site
      end
    end
  end

  def self.current = find_or_create_by!(church: ActsAsTenant.current_tenant) { |site| site.name = ActsAsTenant.current_tenant.name }.tap(&:install_starter_pages!)

  def theme = Site::Theme.fetch(theme_key)
  def settings = theme.default_settings.merge(theme_settings.to_h.compact_blank)
  def layout = layout_liquid.presence || theme.layout
  def custom_layout? = layout_liquid.present?

  def primary_domain = domains.verified.find_by(primary: true) || domains.verified.first
  def default_host = DemoTunnel.site_host_for(church) || "#{church.subdomain}.#{Rails.configuration.x.sites_domain}"
  def host = primary_domain&.hostname || default_host

  def base_url
    return "https://#{host}" if Rails.env.production? || DemoTunnel.site_host_for(church)

    "http://#{host}#{":#{Rails.configuration.x.dev_port}" if Rails.configuration.x.dev_port.presence}"
  end

  def home_page = pages.find_by(slug: "")
  def nav_pages = pages.where(show_in_nav: true).where.not(published_at: nil)

  # Every cached page is keyed on this; bumping it clears the site's cache.
  def expire_cache! = self.class.where(id:).update_all("content_version = content_version + 1, updated_at = now()")

  def install_starter_pages!
    return if pages.exists?

    Site::Starters.install!(self)
  end
end
