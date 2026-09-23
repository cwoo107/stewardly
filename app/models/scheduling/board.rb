# The grid a leader schedules on: occurrences (columns) by the team's positions (rows).
# Service occurrences are created for the range as needed; event occurrences appear
# when the event needs one of the team's positions.
class Scheduling::Board
  Cell = Data.define(:occurrence, :position, :assignments, :needed) do
    def open_slots = [ needed - assignments.count { |a| !a.declined? }, 0 ].max
    def dom_id = "cell_#{occurrence.class.name.underscore}_#{occurrence.id}_position_#{position.id}"
  end

  attr_reader :team, :range

  def initialize(team:, range:)
    @team = team
    @range = range
  end

  def positions
    @positions ||= team.positions.alphabetical.to_a
  end

  def occurrences
    @occurrences ||= (service_occurrences + event_occurrences).sort_by(&:starts_at)
  end

  def cell(occurrence, position)
    Cell.new(occurrence:, position:,
      assignments: assignments_by_slot[[ occurrence.class.name, occurrence.id, position.id ]] || [],
      needed: needs_by_slot[[ occurrence.class.name, occurrence.id, position.id ]].to_i)
  end

  # Conflict notes for an assignment on the board, computed for the whole board
  # in two queries: blocked out that day, or serving somewhere else that day.
  def conflicts_for(assignment)
    notes = []
    notes << "Blocked out that day" if blocked.include?([ assignment.person_id, assignment.local_date ])
    others = serving_elsewhere[[ assignment.person_id, assignment.local_date ]].to_a
      .reject { |other| other.schedulable_type == assignment.schedulable_type && other.schedulable_id == assignment.schedulable_id }
    notes + others.map { |other| "Also serving #{other.position.name} at #{other.title}" }
  end

  # Volunteer load for an assignment's person as of its date (the assignment included).
  def load_for(assignment)
    loads.for(assignment.person_id, as_of: assignment.local_date)
  end

  # Each team member's load today, for the roster.
  def roster_load_for(person_id) = loads.for(person_id, as_of: team.church.today)

  def open_slot_count
    occurrences.sum { |occurrence| positions.sum { |position| cell(occurrence, position).open_slots } }
  end

  private
    def services
      @services ||= WorshipService.active.where(id: PositionNeed.where(needable_type: "WorshipService", position: positions).select(:needable_id)).to_a
    end

    def service_occurrences
      services.each { |service| service.ensure_occurrences!(range) }
      ServiceOccurrence.where(worship_service: services, local_date: range, cancelled: false).includes(worship_service: :position_needs).to_a
    end

    def event_occurrences
      events = Event.where.not(status: "cancelled").where(id: PositionNeed.where(needable_type: "Event", position: positions).select(:needable_id))
      EventOccurrence.where(event: events, local_date: range, cancelled: false).includes(event: :position_needs).to_a
    end

    def assignments_by_slot
      @assignments_by_slot ||= Assignment.where(position: positions, schedulable: occurrences).includes(:person)
        .sort_by { |assignment| [ assignment.person.last_name, assignment.person.first_name ] }
        .group_by { |assignment| [ assignment.schedulable_type, assignment.schedulable_id, assignment.position_id ] }
    end

    def board_assignments = assignments_by_slot.values.flatten

    def loads
      @loads ||= Volunteering::LoadAssessment.new(people: (board_assignments.map(&:person_id) + team.team_memberships.pluck(:person_id)).uniq, church: team.church)
    end

    def blocked
      @blocked ||= begin
        people = board_assignments.map(&:person_id).uniq
        Blockout.where(person_id: people).where(starts_on: ..range.last, ends_on: range.first..).flat_map do |blockout|
          (([ blockout.starts_on, range.first ].max)..([ blockout.ends_on, range.last ].min)).map { |date| [ blockout.person_id, date ] }
        end.to_set
      end
    end

    def serving_elsewhere
      @serving_elsewhere ||= Assignment.active.where(person_id: board_assignments.map(&:person_id).uniq, local_date: range)
        .includes(:position, :schedulable).group_by { |assignment| [ assignment.person_id, assignment.local_date ] }
    end

    def needs_by_slot
      @needs_by_slot ||= occurrences.each_with_object({}) do |occurrence, needs|
        occurrence.position_needs.each do |need|
          needs[[ occurrence.class.name, occurrence.id, need.position_id ]] = need.quantity if positions.any? { |p| p.id == need.position_id }
        end
      end
    end
end
