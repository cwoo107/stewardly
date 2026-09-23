class Insights::Detectors::UnderusedVolunteers < Insights::Detector
  self.kind = "underused_volunteers"
  self.label = "Underused volunteers"
  self.audience_permission = "manage_schedules"

  def findings
    teams = Team.includes(:ministry, team_memberships: :person).to_a
    loads = Volunteering::LoadAssessment.new(people: teams.flat_map { |team| team.team_memberships.map(&:person_id) }.uniq, church: @church)
    teams.filter_map do |team|
      underused = team.team_memberships.map(&:person).select { |person| loads.for(person, as_of: @today).level == "underused" }
      next if underused.empty?

      Finding.build(subject: team, severity: "low", title: "#{plural(underused.size, "volunteer")} on #{team.name} #{underused.one? ? "hasn't" : "haven't"} been scheduled in a while",
        detail: underused.first(5).map(&:name).to_sentence, data: { "count" => underused.size },
        action_label: "Open the schedule", action_path: team_schedule_path(team), audience_user_ids: ministry_leader_ids(team.ministry_id))
    end
  end
end
