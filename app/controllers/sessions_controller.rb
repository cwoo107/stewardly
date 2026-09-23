class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  skip_after_action :verify_authorized
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }

  layout "auth"

  def new
  end

  def create
    # User is tenant-scoped, so this only matches accounts at the current church.
    if user = User.authenticate_by(params.permit(:email_address, :password))
      start_new_session_for user
      redirect_to after_authentication_url
    else
      redirect_to new_session_path, alert: "Try another email address or password."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end
end
