class Platform::SessionsController < Platform::BaseController
  allow_unauthenticated_platform_access only: %i[ new create ]
  skip_after_action :verify_authorized
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_platform_session_path, alert: "Try again later." }

  def new
  end

  def create
    if platform_admin = PlatformAdmin.authenticate_by(params.permit(:email_address, :password))
      start_new_platform_session_for platform_admin
      redirect_to platform_root_path
    else
      redirect_to new_platform_session_path, alert: "Try another email address or password."
    end
  end

  def destroy
    terminate_platform_session
    redirect_to new_platform_session_path, status: :see_other
  end
end
