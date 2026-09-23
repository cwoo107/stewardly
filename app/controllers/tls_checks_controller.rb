# Asked by the TLS proxy in front of the app (e.g. Caddy's on_demand_tls "ask") before it
# requests a certificate for a hostname: 200 for the app's own hosts and verified church
# domains, 404 otherwise, so nobody can make us request certificates for arbitrary names.
class TlsChecksController < ActionController::API
  def show
    token = Rails.configuration.x.tls_ask_token
    return head(:forbidden) if token.present? && !ActiveSupport::SecurityUtils.secure_compare(params[:token].to_s, token)

    allowed?(params[:domain].to_s.downcase.strip) ? head(:ok) : head(:not_found)
  end

  private
    def allowed?(domain)
      return false if domain.blank?

      config = Rails.configuration.x
      church_subdomain = ->(suffix) { domain.end_with?(".#{suffix}") && Church.exists?(subdomain: domain.delete_suffix(".#{suffix}")) }
      [ config.app_domain, config.sites_cname_target ].include?(domain) || church_subdomain.(config.app_domain) ||
        church_subdomain.(config.sites_domain) || SiteDomain.verified_host?(domain)
    end
end
