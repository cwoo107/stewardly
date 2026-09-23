class PositionPolicy < ApplicationPolicy
  def create? = TeamPolicy.new(user, record.team).update?
  def destroy? = create?
end
