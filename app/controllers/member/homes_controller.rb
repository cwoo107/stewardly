class Member::HomesController < Member::BaseController
  def show
    @announcements = Announcement.current(Time.current, today).limit(5)
    @awaiting_reply = person.assignments.pending.upcoming(today).includes(:schedulable, :position)
    @upcoming_serving = person.assignments.accepted.upcoming(today).includes(:schedulable, :position).limit(3)
    @registrations = person.registrations.active.joins(:event_occurrence).merge(EventOccurrence.upcoming)
      .includes(event_occurrence: :event).order("event_occurrences.starts_at").limit(3)
    @events = EventOccurrence.upcoming.joins(:event).merge(Event.listed_for_members).includes(:event).chronological.limit(4)
  end
end
