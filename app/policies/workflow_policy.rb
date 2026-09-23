class WorkflowPolicy < ApplicationPolicy
  def index? = can?(:manage_workflows)
  def show? = can?(:manage_workflows)
  def create? = can?(:manage_workflows)
  def update? = can?(:manage_workflows)
  def destroy? = can?(:manage_workflows)
  def publish? = update?
  def pause? = update?
  def resume? = update?
  def stop_runs? = update?

  # Letting AI messages go out without review is a church admin's call.
  def auto_send? = user.present? && user.church_admin?

  class Scope < Scope
    def resolve
      can?(:manage_workflows) ? scope.all : scope.none
    end
  end
end
