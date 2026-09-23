class PositionQualificationPolicy < ApplicationPolicy
  def create? = TeamSchedulePolicy.new(user, record.position.team).show?
  def destroy? = create?
end
