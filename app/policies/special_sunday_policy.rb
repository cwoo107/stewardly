class SpecialSundayPolicy < ApplicationPolicy
  def index? = can?(:view_attendance) || can?(:record_attendance)
  def create? = can?(:record_attendance)
  def update? = create?
  def destroy? = create?

  class Scope < Scope
    def resolve = (can?(:view_attendance) || can?(:record_attendance)) ? scope.all : scope.none
  end
end
