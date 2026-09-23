class Insights::Detectors::UnfilledPositions < Insights::Detector
  self.kind = "unfilled_positions"
  self.label = "Unfilled positions this Sunday"
  self.audience_permission = "manage_schedules"

  def findings
    sunday = @today.sunday? ? @today : @today.next_occurring(:sunday)
    Team.includes(:ministry).filter_map do |team|
      open = Scheduling::Board.new(team:, range: sunday..sunday).open_slot_count
      next if open.zero?

      Finding.build(subject: team, severity: (sunday - @today) <= 3 ? "high" : "medium",
        title: "#{plural(open, "open spot")} on #{team.name} for #{I18n.l(sunday, format: :long)}", data: { "open" => open, "date" => sunday.iso8601 },
        action_label: "Fill the schedule", action_path: team_schedule_path(team), audience_user_ids: ministry_leader_ids(team.ministry_id))
    end
  end

  # Weekly: a new Sunday is a new insight.
  def fingerprint(finding) = "#{super}:#{finding.data["date"]}"
end
