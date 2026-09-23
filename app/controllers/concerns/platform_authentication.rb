# Sign-in for platform admins on the bare app domain. Mirrors Authentication,
# but with its own model and cookie so church and platform sessions never mix.
module PlatformAuthentication
  extend ActiveSupport::Concern

  included do
    before_action :require_platform_authentication
    helper_method :platform_authenticated?
  end

  class_methods do
    def allow_unauthenticated_platform_access(**options)
      skip_before_action :require_platform_authentication, **options
    end
  end

  private
    def platform_authenticated?
      resume_platform_session
    end

    def require_platform_authentication
      resume_platform_session || redirect_to(new_platform_session_path)
    end

    def resume_platform_session
      Current.platform_session ||= find_platform_session_by_cookie
    end

    def find_platform_session_by_cookie
      PlatformSession.find_by(id: cookies.signed[:platform_session_id]) if cookies.signed[:platform_session_id]
    end

    def start_new_platform_session_for(platform_admin)
      platform_admin.platform_sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
        Current.platform_session = session
        cookies.signed[:platform_session_id] = { value: session.id, httponly: true, same_site: :lax, expires: 12.hours }
      end
    end

    def terminate_platform_session
      Current.platform_session.destroy
      cookies.delete(:platform_session_id)
    end
end
