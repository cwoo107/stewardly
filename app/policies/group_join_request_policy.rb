# Leaders decide: anyone who manages the group, or a leader of the group who can sign in.
class GroupJoinRequestPolicy < ApplicationPolicy
  def update? = GroupPolicy.new(user, record.group).update? || group_leader?
  def create_own? = user.present? && record.person_id == user.person_id

  private
    def group_leader?
      user.present? && record.group.group_memberships.leader.exists?(person_id: user.person_id)
    end
end
