class TeamMembershipPolicy < ApplicationPolicy
  def create? = TeamPolicy.new(user, record.team).update?
  def destroy? = create?
  # Monthly maximums are a scheduling setting.
  def update? = create? || TeamSchedulePolicy.new(user, record.team).show?
end
