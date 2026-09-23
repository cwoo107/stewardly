class PositionNeedPolicy < ApplicationPolicy
  def create? = manage?
  def update? = manage?
  def destroy? = manage?

  private
    def manage?
      case record.needable
      when WorshipService then can?(:manage_schedules)
      when Event then EventPolicy.new(user, record.needable).update?
      else false
      end
    end
end
