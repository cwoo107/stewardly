class Insights::Detectors::NoRecentContact < Insights::Detector
  self.kind = "no_recent_contact"
  self.label = "No contact in a while"
  self.audience_permission = "view_people"

  def findings
    days = @church.no_contact_days
    condition = Segment::Condition.new("type" => "no_touchpoint", "days" => days)
    people = Person.unmerged.where(membership_status: %w[ member regular_attender ]).merge(condition.relation)
    count = people.count
    return [] if count.zero?

    [ Finding.build(severity: count >= 25 ? "medium" : "low", title: "#{plural(count, "member or regular attender")} with no contact in #{days} days",
      detail: people.alphabetical.limit(5).map(&:name).to_sentence, data: { "count" => count, "days" => days },
      action_label: "Build a segment", action_path: new_segment_path(conditions: [ { type: "membership_status", statuses: %w[ member regular_attender ] }, { type: "no_touchpoint", days: } ])) ]
  end
end
