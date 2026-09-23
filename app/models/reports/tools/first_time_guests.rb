class Reports::Tools::FirstTimeGuests < Reports::Tool
  self.tool_name = "first_time_guests"
  self.title = "First-time guests"
  self.description = "People checked in for the first time in a date range, and how many came back at least once more."
  self.permission = "view_people"
  self.parameters = {
    from: { type: "string", format: "date", description: "Start date (YYYY-MM-DD). Default: 90 days ago.", label: "From", default: -> { @today - 90 } },
    to: { type: "string", format: "date", description: "End date (YYYY-MM-DD). Default: today.", label: "To", default: -> { @today } }
  }

  private
    def call(args)
      range = args["from"].in_time_zone(@church.zone).beginning_of_day..args["to"].in_time_zone(@church.zone).end_of_day
      firsts = Attendance.where(first_time: true, checked_in_at: range)
      person_ids = firsts.pluck(:person_id)
      returned = Attendance.where(person_id: person_ids, first_time: false).distinct.count(:person_id)
      headcount_guests = AttendanceCount.joins(:service_occurrence).where(service_occurrences: { local_date: args["from"]..args["to"] }).sum(:first_time_guests)
      Result.build(figures: { "First-time check-ins" => person_ids.size, "Came back" => returned, "Came back (%)" => percent(returned, person_ids.size),
        "First-time guests in headcounts" => headcount_guests }, note: "Check-ins are named people; headcounts are tallies entered with Sunday counts.")
    end
end
