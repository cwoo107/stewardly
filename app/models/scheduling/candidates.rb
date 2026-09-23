# Who could serve in a position at an occurrence, best first, with the reasons.
#
# Eligible: on the position's team, qualified (when the position lists
# qualifications), not blocked out, not already on this occurrence, and under their
# monthly maximum for the team. People serving elsewhere that day are included but
# flagged as conflicts (auto-fill skips them).
#
# Ranked by: no conflict, volunteer load if they served this date (at risk last,
# elevated next; Volunteering::LoadAssessment), fewest assignments in the last
# 8 weeks, fewest recent declines, then longest since last serving.
class Scheduling::Candidates
  LOOKBACK = 8.weeks

  LOAD_RANK = { "at_risk" => 2, "elevated" => 1 }.freeze

  Candidate = Data.define(:person, :recent_count, :recent_declines, :last_served_on, :conflicts, :load) do
    def conflict? = conflicts.any?

    def reasons
      [
        ("would be #{load.label.downcase}: #{load.reasons.to_sentence}" if load && LOAD_RANK.key?(load.level)),
        recent_count.zero? ? "hasn't served in 8 weeks" : "served #{recent_count} #{"time".pluralize(recent_count)} in 8 weeks",
        ("declined #{recent_declines} recently" if recent_declines.positive?),
        ("also scheduled: #{conflicts.map(&:title).uniq.to_sentence}" if conflict?)
      ].compact
    end

    def sort_key = [ conflict? ? 1 : 0, LOAD_RANK.fetch(load&.level, 0), recent_count, recent_declines, last_served_on || Date.new(1900), person.last_name, person.first_name ]
  end

  def initialize(occurrence:, position:)
    @occurrence = occurrence
    @position = position
    @date = occurrence.local_date
  end

  def all
    people = eligible_people
    return [] if people.empty?

    ids = people.map(&:id)
    history = Assignment.where(person_id: ids, position: team_positions, local_date: (@date - LOOKBACK)...@date)
    recent = history.active.group(:person_id).count
    declines = history.declined.group(:person_id).count
    last_served = Assignment.where(person_id: ids, position: team_positions, local_date: ...@date).active.group(:person_id).maximum(:local_date)
    conflicts = Assignment.active.on(@date).where(person_id: ids).where.not(schedulable: @occurrence).includes(:schedulable).group_by(&:person_id)
    loads = Volunteering::LoadAssessment.new(people: ids, church: @occurrence.church)

    people.map do |person|
      Candidate.new(person:, recent_count: recent[person.id].to_i, recent_declines: declines[person.id].to_i,
        last_served_on: last_served[person.id], conflicts: Array(conflicts[person.id]).map(&:schedulable),
        load: loads.for(person, as_of: @date, extra_date: @date))
    end.sort_by(&:sort_key)
  end

  def best(limit)
    all.reject(&:conflict?).first(limit)
  end

  private
    def team = @position.team
    def team_positions = team.positions

    def eligible_people
      memberships = team.team_memberships.includes(:person).reject { |membership| membership.person.merged? }
      qualified_ids = @position.position_qualifications.pluck(:person_id)
      memberships = memberships.select { |m| qualified_ids.include?(m.person_id) } if qualified_ids.any?

      blocked = Blockout.covering(@date).where(person_id: memberships.map(&:person_id)).pluck(:person_id)
      here = @occurrence.assignments.active.pluck(:person_id)
      month = Assignment.active.where(position: team_positions, local_date: @date.all_month).group(:person_id).count

      memberships.reject do |membership|
        blocked.include?(membership.person_id) || here.include?(membership.person_id) ||
          (membership.max_per_month && month[membership.person_id].to_i >= membership.max_per_month)
      end.map(&:person)
    end
end
