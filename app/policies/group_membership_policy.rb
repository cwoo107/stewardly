class GroupMembershipPolicy < ApplicationPolicy
  def create? = GroupPolicy.new(user, record.group).update?
  def update? = create?
  def destroy? = create?
end
