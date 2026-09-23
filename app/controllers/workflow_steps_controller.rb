# Adding, configuring, reordering, and removing steps in a workflow's draft. Step
# settings are edited inline (a Turbo Frame per step).
class WorkflowStepsController < ApplicationController
  before_action :set_workflow

  def create
    step = @workflow.add_step!(params.expect(:type), parent_id: params[:parent_id].presence, branch: params[:branch].presence)
    redirect_to edit_workflow_path(@workflow, editing: step["id"], anchor: "step_#{step["id"]}"), status: :see_other
  rescue ArgumentError => error
    redirect_to edit_workflow_path(@workflow), alert: error.message
  end

  def edit
    @step = @workflow.draft.find(params[:id]) or raise ActiveRecord::RecordNotFound
  end

  def update
    step = @workflow.draft.find(params[:id]) or raise ActiveRecord::RecordNotFound
    config = Workflow::StepParams.new(step, params, user: Current.user).config
    audit_auto_send(step, config)
    @workflow.update_step!(step["id"], config)
    redirect_to edit_workflow_path(@workflow, anchor: "step_#{step["id"]}"), status: :see_other
  end

  def destroy
    @workflow.remove_step!(params[:id])
    redirect_to edit_workflow_path(@workflow), notice: "Step removed.", status: :see_other
  end

  def move
    @workflow.move_step!(params[:id], params.expect(:position))
    head :no_content
  end

  private
    def set_workflow
      @workflow = Workflow.find(params.expect(:workflow_id))
      authorize @workflow, :update?
    end

    def audit_auto_send(step, config)
      return unless step["type"] == "ai_draft" && step.dig("config", "auto_send").present? != config["auto_send"].present?

      AuditEvent.record!(action: config["auto_send"] ? "workflow.auto_send_enabled" : "workflow.auto_send_disabled", auditable: @workflow,
        metadata: { "workflow_name" => @workflow.name, "step_id" => step["id"] })
    end
end
