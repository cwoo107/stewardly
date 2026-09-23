class Reports::Tools::AttendanceSeries < Reports::Tool
  self.tool_name = "attendance_series"
  self.title = "Attendance over time"
  self.description = "Headcounts from recorded services (in person and online), totalled by week or month, over a date range."
  self.permission = "view_attendance"
  self.parameters = {
    from: { type: "string", format: "date", description: "Start date (YYYY-MM-DD). Default: 12 weeks ago.", label: "From", default: -> { @today - 84 } },
    to: { type: "string", format: "date", description: "End date (YYYY-MM-DD). Default: today.", label: "To", default: -> { @today } },
    interval: { type: "string", enum: %w[ week month ], description: "Group by week or month. Default: week.", label: "By", default: "week" }
  }

  private
    def call(args)
      counts = AttendanceCount.joins(:service_occurrence).where(service_occurrences: { local_date: args["from"]..args["to"] }).includes(:service_occurrence).to_a
      grouped = counts.group_by { |count| args["interval"] == "month" ? count.service_occurrence.local_date.beginning_of_month : count.service_occurrence.local_date.beginning_of_week(:sunday) }
      rows = grouped.sort.map { |start, group| [ start.iso8601, group.sum(&:total), group.sum(&:in_person), group.sum(&:online), group.sum(&:first_time_guests) ] }
      totals = rows.map { |row| row[1] }
      Result.build(figures: { "Services counted" => counts.size, "Total attendance" => totals.sum, "Average per #{args["interval"]}" => totals.empty? ? 0 : (totals.sum.to_f / totals.size).round(1) },
        tables: [ table("By #{args["interval"]}", [ "#{args["interval"].capitalize} starting", "Total", "In person", "Online", "First-time guests" ], rows) ])
    end
end
