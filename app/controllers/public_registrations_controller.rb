# Registration from the public event page. Signed-in members register as themselves;
# guests give a name and email (matched with Person::Intake's fill-blanks rule).
class PublicRegistrationsController < ApplicationController
  include PublicEventLookup
  include PublicSubmissionProtection

  allow_unauthenticated_access
  skip_after_action :verify_authorized # visibility is enforced by PublicEventLookup
  before_action :resume_session
  before_action :set_public_event
  before_action :set_occurrence

  protect_submissions only: :create, with: -> { rerender("That's a lot of registrations. Please wait a minute and try again.", :too_many_requests) }

  layout "public"

  def create
    return rerender("Registration isn't open right now.", :unprocessable_content) unless @event.registration_open?
    return redirect_to(public_event_path(@event.slug), notice: "Thanks! Check your email for details.") if suspected_bot?

    @response = Form::Response.new(@event.registration_form, params.fetch(:answers, {})) if @event.registration_form
    intake = Person::Intake.new(user: Current.user, **params.fetch(:registrant, {}).permit(:first_name, :last_name, :email).to_h.symbolize_keys)
    return rerender("Please check the highlighted answers.", :unprocessable_content) if @response && !@response.valid?

    person = intake.person
    return rerender("Please enter your first name, last name, and email.", :unprocessable_content) unless person && (Current.user || params.dig(:registrant, :email).present?)

    registration = Registration.transaction do
      submission = FormSubmission.build_from(@event.registration_form, @response, user: Current.user, ip_address: request.remote_ip).tap(&:save!) if @response
      Registration::Booking.new(occurrence: @occurrence, person:, party_size: params[:party_size], form_submission: submission).book!.registration
    end
    redirect_to manage_registration_path(registration.manage_token), status: :see_other
  end

  private
    def set_occurrence
      @occurrence = @event.occurrences.upcoming.find(params.expect(:occurrence_id))
    end

    def rerender(message, status)
      flash.now[:alert] = message
      @occurrences = @event.upcoming_occurrences
      render "public_events/show", status: status
    end
end
