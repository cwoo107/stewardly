class WorkflowRunPolicy < ApplicationPolicy
  def index? = can?(:manage_workflows)
  def show? = can?(:manage_workflows)
  def retry? = can?(:manage_workflows) && record.failed?
  def cancel? = can?(:manage_workflows) && record.in_flight?

  class Scope < Scope
    def resolve
      can?(:manage_workflows) ? scope.all : scope.none
    end
  end
end
