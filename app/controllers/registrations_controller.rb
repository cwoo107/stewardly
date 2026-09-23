# Organizer views of registrations: list/export, walk-ins, check-in, and cancelling.
class RegistrationsController < ApplicationController
  before_action :set_event

  def index
    @occurrences = @event.occurrences.includes(registrations: :person)
    respond_to do |format|
      format.html
      format.csv { send_data registrations_csv, filename: "#{@event.slug}-registrations-#{Current.church.today.iso8601}.csv", type: :csv }
    end
  end

  # Walk-in at check-in: an existing person, or a quick new guest.
  def create
    occurrence = @event.occurrences.find(params.expect(:occurrence_id))
    person = if params[:person_id].present?
      Person.unmerged.find(params[:person_id])
    else
      Person::Intake.new(email: params[:email], first_name: params[:first_name], last_name: params[:last_name]).person
    end
    return redirect_to(event_occurrence_check_in_path(@event, occurrence), alert: "Enter a first and last name.", status: :see_other) unless person

    registration = Registration::Booking.new(occurrence:, person:, party_size: params.fetch(:party_size, 1)).book!.registration
    registration.check_in! if registration.confirmed?
    redirect_to event_occurrence_check_in_path(@event, occurrence), notice: "#{person.name} checked in.", status: :see_other
  end

  def update
    registration = @event.registrations.find(params.expect(:id))
    case params.expect(:change)
    when "check_in" then registration.check_in!
    when "undo_check_in" then registration.undo_check_in!
    when "cancel" then registration.cancel!
    end

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace(helpers.dom_id(registration), partial: "event_check_ins/registration", locals: { registration:, event: @event }) }
      format.html { redirect_back_or_to event_registrations_path(@event), status: :see_other }
    end
  end

  private
    def set_event
      @event = authorize policy_scope(Event).find(params.expect(:event_id)), :update?
    end

    def registrations_csv
      CSV.generate do |csv|
        csv << [ "Date", "Name", "Email", "Party size", "Status", "Registered at", "Checked in" ]
        @occurrences.each do |occurrence|
          occurrence.registrations.sort_by(&:created_at).each do |registration|
            csv << [ I18n.l(occurrence.starts_at, format: :short), registration.person.full_name, registration.person.email,
              registration.party_size, registration.status, registration.created_at.iso8601, registration.checked_in_at&.iso8601 ]
          end
        end
      end
    end
end
