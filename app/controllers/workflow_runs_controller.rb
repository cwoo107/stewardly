class WorkflowRunsController < ApplicationController
  before_action :set_workflow

  def index
    authorize WorkflowRun
    scope = policy_scope(@workflow.runs).includes(:person, :workflow_version).recent_first
    scope = scope.where(status: params[:status]) if WorkflowRun.statuses.key?(params[:status])
    @pagy, @runs = pagy(scope)
  end

  def show
    @run = authorize @workflow.runs.find(params.expect(:id))
    @executions = @run.step_executions.index_by(&:step_id)
  end

  def retry
    run = authorize @workflow.runs.find(params.expect(:id))
    run.retry!
    redirect_to workflow_run_path(@workflow, run), notice: "Trying that step again."
  end

  def cancel
    run = authorize @workflow.runs.find(params.expect(:id))
    run.cancel!("Stopped by #{Current.user.name}")
    redirect_to workflow_run_path(@workflow, run), notice: "Run stopped.", status: :see_other
  end

  private
    def set_workflow
      @workflow = Workflow.find(params.expect(:workflow_id))
    end
end
