class Member::RegistrationsController < Member::BaseController
  def create
    event = Event.listed_for_members.includes(registration_form: :fields).find(params.expect(:event_id))
    occurrence = event.occurrences.upcoming.find(params.expect(:occurrence_id))
    return redirect_to(member_event_path(event), alert: "Registration isn't open right now.") unless event.registration_open?

    response = Form::Response.new(event.registration_form, params.fetch(:answers, {})) if event.registration_form
    return redirect_to(member_event_path(event), alert: "Please answer: #{response.errors.keys.to_sentence}.") if response && !response.valid?

    registration = Registration.transaction do
      submission = FormSubmission.build_from(event.registration_form, response, user: Current.user).tap(&:save!) if response
      Registration::Booking.new(occurrence:, person:, party_size: params[:party_size], form_submission: submission).book!.registration
    end
    redirect_to member_event_path(event), notice: registration.waitlisted? ? "It's full, so you're on the waitlist." : "You're registered!", status: :see_other
  end

  def destroy
    registration = person.registrations.find(params.expect(:id))
    authorize registration, :cancel_own?
    registration.cancel!
    redirect_to member_event_path(registration.event), notice: "Registration cancelled.", status: :see_other
  end
end
