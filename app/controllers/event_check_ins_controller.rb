# The day-of check-in screen for one event date.
class EventCheckInsController < ApplicationController
  def show
    @event = authorize policy_scope(Event).find(params.expect(:event_id)), :check_in?
    @occurrence = @event.occurrences.find(params.expect(:occurrence_id))
    registrations = @occurrence.registrations.active.includes(:person).joins(:person).merge(Person.alphabetical)
    registrations = registrations.merge(Person.search(params[:q])) if params[:q].present?
    @registrations = registrations
  end
end
