class Insights::Detectors::GroupsAtCapacity < Insights::Detector
  self.kind = "group_at_capacity"
  self.label = "Groups at capacity"
  self.audience_permission = "manage_ministries"

  def findings
    Group.active.where.not(capacity: nil).includes(:group_memberships).select(&:full?).map do |group|
      leader_user_ids = User.where(person_id: group.group_memberships.select(&:leader?).map(&:person_id)).pluck(:id)
      Finding.build(subject: group, severity: "low", title: "#{group.name} is full (#{group.capacity} of #{group.capacity})",
        detail: "New people who want to join will be waitlisted. Consider opening another group nearby.", data: { "capacity" => group.capacity },
        action_label: "Open #{group.name}", action_path: group_path(group), audience_user_ids: leader_user_ids + ministry_leader_ids(group.ministry_id))
    end
  end
end
