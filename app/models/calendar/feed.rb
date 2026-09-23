# Everything on the church calendar for a date range, filtered by who is looking.
#   staff:  all events (drafts only for event managers), services, and course sessions
#   member: published public/members events, services, their classes, and their own assignments
class Calendar::Feed
  Item = Data.define(:kind, :title, :starts_at, :ends_at, :local_date, :path, :detail)

  def initialize(viewer:, range:, audience:)
    @viewer = viewer
    @range = range
    @audience = audience
  end

  def items
    @items ||= (events + services + sessions + own_assignments).sort_by(&:starts_at)
  end

  def by_date
    items.group_by(&:local_date)
  end

  private
    def routes = Rails.application.routes.url_helpers
    def member? = @audience == :member

    def events
      scope = EventOccurrence.where(local_date: @range, cancelled: false).joins(:event).includes(:event)
      scope = if member?
        scope.merge(Event.listed_for_members)
      elsif @viewer.can?(:manage_events)
        scope.merge(Event.where.not(status: "cancelled"))
      else
        scope.merge(Event.published)
      end

      scope.map do |occurrence|
        Item.new(kind: "event", title: occurrence.title, starts_at: occurrence.starts_at, ends_at: occurrence.ends_at,
          local_date: occurrence.local_date, detail: occurrence.event.location_summary.presence,
          path: member? ? routes.member_event_path(occurrence.event) : routes.event_path(occurrence.event))
      end
    end

    # Computed, not stored: calendars never write occurrences.
    def services
      WorshipService.active.includes(:campus).flat_map do |service|
        service.dates_between(@range).map do |date|
          starts_at, ends_at = service.times_on(date)
          Item.new(kind: "service", title: service.name, starts_at:, ends_at:, local_date: date, detail: service.campus&.name, path: nil)
        end
      end
    end

    def sessions
      scope = CourseSession.where(local_date: @range).includes(course_offering: :course)
      scope = scope.where(course_offering_id: Enrollment.current.where(person: @viewer.person).select(:course_offering_id)) if member?

      scope.map do |session|
        Item.new(kind: "class", title: session.course_offering.name, starts_at: session.starts_at, ends_at: session.ends_at,
          local_date: session.local_date, detail: session.topic,
          path: member? ? routes.member_courses_path : routes.course_offering_path(session.course_offering))
      end
    end

    def own_assignments
      return [] unless member?

      Assignment.active.where(person: @viewer.person, local_date: @range).includes(:schedulable, :position).map do |assignment|
        Item.new(kind: "serving", title: "Serving: #{assignment.position.name}", starts_at: assignment.starts_at, ends_at: assignment.ends_at,
          local_date: assignment.local_date, detail: assignment.title, path: routes.member_assignments_path)
      end
    end
end
