# Resolves the church from the request host (a church subdomain, or a church website's
# host for forms and events served there), scopes every tenant model to it, and runs
# the request in the church's time zone.
module ChurchTenancy
  extend ActiveSupport::Concern

  included do
    set_current_tenant_through_filter
    before_action :set_current_church
    around_action :use_church_time_zone
  end

  private
    def set_current_church
      site = Site.for_host(request.host) if SiteHost.site_host_name?(request.host)
      Current.site = site
      church = site ? site.church : Church.find_by_host_subdomain(request.subdomain)
      return render(file: Rails.public_path.join("404.html"), status: :not_found, layout: false) unless church

      set_current_tenant(church)
      Current.church = church
      Current.ip_address = request.remote_ip
    end

    def use_church_time_zone(&)
      Time.use_zone(Current.church.zone, &)
    end
end
