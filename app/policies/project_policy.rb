class ProjectPolicy < ApplicationPolicy
  def index? = can?(:manage_tasks)
  def create? = can?(:manage_tasks)
  def update? = can?(:manage_tasks)
  def destroy? = can?(:manage_tasks)

  class Scope < Scope
    def resolve
      can?(:manage_tasks) ? scope.all : scope.none
    end
  end
end
