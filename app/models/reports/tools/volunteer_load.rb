class Reports::Tools::VolunteerLoad < Reports::Tool
  self.tool_name = "volunteer_load"
  self.title = "Volunteer load"
  self.description = "How many volunteers are underused, healthy, elevated, or at risk of burnout right now."
  self.permission = "manage_schedules"

  private
    def call(_args)
      people = TeamMembership.distinct.pluck(:person_id)
      loads = Volunteering::LoadAssessment.new(people:, church: @church)
      levels = people.map { |id| loads.for(id, as_of: @today).level }.tally
      rows = Volunteering::LoadAssessment::LEVELS.map { |level| [ Volunteering::LoadAssessment::LEVEL_LABELS[level], levels[level].to_i ] }
      Result.build(figures: { "Volunteers" => people.size }.merge(rows.to_h), tables: [ table("By level", [ "Level", "Volunteers" ], rows) ])
    end
end
