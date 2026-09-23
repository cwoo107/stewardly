class Reports::Tools::VolunteerCoverage < Reports::Tool
  self.tool_name = "volunteer_coverage"
  self.title = "Volunteer coverage"
  self.description = "For the coming weeks, how many serving spots each team needs and how many are still open."
  self.permission = "manage_schedules"
  self.parameters = { weeks: { type: "integer", description: "How many weeks ahead. Default 4, at most 12.", label: "Weeks ahead", default: 4 } }

  private
    def call(args)
      range = @today..(@today + args["weeks"].clamp(1, 12) * 7)
      rows = Team.alphabetical.map do |team|
        board = Scheduling::Board.new(team:, range:)
        cells = board.occurrences.flat_map { |occurrence| board.positions.map { |position| board.cell(occurrence, position) } }
        needed = cells.sum(&:needed)
        open = cells.sum(&:open_slots)
        [ team.name, needed, needed - open, open, percent(needed - open, needed) ]
      end.reject { |row| row[1].zero? }
      Result.build(figures: { "Spots needed" => rows.sum { |r| r[1] }, "Filled" => rows.sum { |r| r[2] }, "Open" => rows.sum { |r| r[3] } },
        tables: [ table("By team", [ "Team", "Needed", "Filled", "Open", "Filled (%)" ], rows) ], note: "#{range.first} to #{range.last}.")
    end
end
