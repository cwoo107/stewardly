# Base controller for everything served on a church subdomain.
class ApplicationController < ActionController::Base
  # Order matters: the church is resolved before the session is looked up.
  include ChurchTenancy
  include Authentication
  include Authorization
  include Pagy::Backend

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private
    def pundit_user
      Current.user
    end
end
