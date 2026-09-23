# Volunteers at risk of burnout (one each) and, per team, volunteers who haven't served
# in a long time. Both from Volunteering::LoadAssessment.
class Insights::Detectors::VolunteersAtRisk < Insights::Detector
  self.kind = "volunteer_at_risk"
  self.label = "Volunteers at risk of burnout"
  self.audience_permission = "manage_schedules"

  def findings
    memberships = TeamMembership.includes(:person, team: :ministry).to_a
    loads = Volunteering::LoadAssessment.new(people: memberships.map(&:person_id).uniq, church: @church)
    memberships.group_by(&:person).filter_map do |person, person_memberships|
      load = loads.for(person, as_of: @today)
      next unless load.at_risk?

      teams = person_memberships.map(&:team)
      Finding.build(subject: person, person:, severity: "high", title: "#{person.name} is at risk of burning out",
        detail: load.reasons.to_sentence.upcase_first, data: { "consecutive_weeks" => load.consecutive_weeks, "per_week" => load.per_week, "teams" => load.teams },
        action_label: "See volunteer load", action_path: volunteer_load_path(level: "at_risk"),
        audience_user_ids: ministry_leader_ids(teams.map(&:ministry_id)))
    end
  end
end
