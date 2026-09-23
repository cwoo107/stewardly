class Member::EventsController < Member::BaseController
  def index
    @occurrences = EventOccurrence.upcoming.joins(:event).merge(Event.listed_for_members).includes(:event).chronological.limit(50)
    @mine = person.registrations.active.pluck(:event_occurrence_id, :status).to_h
  end

  def show
    @event = Event.listed_for_members.includes(registration_form: :fields).find(params.expect(:id))
    @occurrences = @event.upcoming_occurrences
    @mine = person.registrations.active.where(event_occurrence: @occurrences).index_by(&:event_occurrence_id)
  end
end
