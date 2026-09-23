# The trigger and entry conditions of a workflow's draft.
class WorkflowTriggersController < ApplicationController
  before_action :set_workflow

  def edit
    @trigger = @workflow.draft.trigger
    @trigger = Workflow::Trigger.new("type" => params[:type]) if params[:type].present? && params[:type] != @trigger.type
    @entry = @workflow.draft.entry
  end

  def update
    trigger = Workflow::Trigger.new(params.fetch(:trigger, {}).permit(:type, config: {}).to_h)
    @workflow.update_trigger!(trigger, params.dig(:workflow_entry, :definition)&.to_unsafe_h || {})
    redirect_to edit_workflow_path(@workflow), notice: "Trigger saved."
  end

  private
    def set_workflow
      @workflow = Workflow.find(params.expect(:workflow_id))
      authorize @workflow, :update?
    end
end
