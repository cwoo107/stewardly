# Groups inside a ministry can be managed by that ministry's leaders.
class GroupPolicy < ApplicationPolicy
  def index? = MinistryPolicy.new(user, Ministry).index?
  def show? = can?(:view_people) || manage? || leader?
  def create? = manage?
  def update? = manage?
  def destroy? = manage?

  private
    def manage? = can?(:manage_ministries) || (user.present? && user.leads?(record.ministry))
    def leader? = user.present? && record.group_memberships.leader.exists?(person_id: user.person_id)

  class Scope < Scope
    def resolve
      return scope.all if can?(:view_people) || can?(:manage_ministries)
      return scope.none unless user

      scope.where(ministry_id: user.led_ministry_ids).or(scope.where(id: GroupMembership.leader.where(person_id: user.person_id).select(:group_id)))
    end
  end
end
