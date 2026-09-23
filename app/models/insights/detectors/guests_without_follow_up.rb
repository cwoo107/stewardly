# First-time guests (last 14 days) with no contact logged since their visit.
class Insights::Detectors::GuestsWithoutFollowUp < Insights::Detector
  self.kind = "guest_without_follow_up"
  self.label = "First-time guests with no follow-up"
  self.audience_permission = "view_people"

  def findings
    visits = Attendance.where(first_time: true, checked_in_at: (@today - 14).beginning_of_day..).includes(:person)
    visits.filter_map do |visit|
      person = visit.person
      next if person.merged? || person.touchpoints.where(occurred_at: visit.checked_in_at..).exists?

      days = (@today - visit.checked_in_at.in_time_zone(@church.zone).to_date).to_i
      Finding.build(subject: person, person:, severity: days >= 3 ? "high" : "medium", title: "#{person.name} visited for the first time #{days.zero? ? "today" : "#{plural(days, "day")} ago"} and hasn't heard from anyone",
        data: { "days_since_visit" => days }, action_label: "Open #{person.first_name}", action_path: person_path(person))
    end
  end
end
