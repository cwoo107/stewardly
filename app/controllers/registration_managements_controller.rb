# "View or cancel" from the registration email: the token is the key, no sign-in needed.
# Viewing never changes anything; cancelling is a DELETE from a button.
class RegistrationManagementsController < ApplicationController
  allow_unauthenticated_access
  skip_after_action :verify_authorized # the secret token is the authorization
  before_action :set_registration

  layout "public"

  def show
  end

  def destroy
    @registration.cancel! unless @registration.cancelled?
    redirect_to manage_registration_path(@registration.manage_token), notice: "Your registration is cancelled.", status: :see_other
  end

  private
    def set_registration
      @registration = Registration.includes(event_occurrence: :event).find_by!(manage_token: params.expect(:token).to_s)
    end
end
