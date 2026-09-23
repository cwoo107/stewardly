# Base controller for the platform console on the bare app domain.
class Platform::BaseController < ActionController::Base
  include PlatformAuthentication
  include Authorization

  layout "platform"

  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action { Current.ip_address = request.remote_ip }

  private
    def pundit_user
      Current.platform_admin
    end

    def authorize(record, query = nil)
      super([ :platform, record ], query)
    end

    def policy_scope(scope)
      super([ :platform, scope ])
    end
end
