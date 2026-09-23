class WorshipServicePolicy < ApplicationPolicy
  def index? = can?(:manage_schedules)
  def create? = can?(:manage_schedules)
  def update? = can?(:manage_schedules)
  def destroy? = can?(:manage_schedules)

  class Scope < Scope
    def resolve = can?(:manage_schedules) ? scope.all : scope.none
  end
end
