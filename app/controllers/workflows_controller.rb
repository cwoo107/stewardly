class WorkflowsController < ApplicationController
  before_action :set_workflow, only: %i[ show edit update destroy publish pause resume stop_runs ]

  def index
    authorize Workflow
    Workflow::Starters.install!
    @workflows = policy_scope(Workflow).includes(:current_version).alphabetical
    @in_flight = WorkflowRun.in_flight.group(:workflow_id).count
    @last_started = WorkflowRun.group(:workflow_id).maximum(:started_at)
  end

  def show
    @counts = @workflow.runs.group(:status).count
    @runs = @workflow.runs.includes(:person, :workflow_version).recent_first.limit(10)
  end

  def new
    @workflow = authorize Workflow.new
  end

  def create
    @workflow = authorize Workflow.new(workflow_params.merge(created_by: Current.user))
    if @workflow.save
      redirect_to edit_workflow_trigger_path(@workflow), notice: "Workflow created. Choose what starts it."
    else
      render :new, status: :unprocessable_content
    end
  end

  # The builder.
  def edit
    @problems = @workflow.draft.errors
  end

  def update
    if @workflow.update(workflow_params)
      redirect_to edit_workflow_path(@workflow), notice: "Saved."
    else
      @problems = @workflow.draft.errors
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @workflow.destroy!
    redirect_to workflows_path, notice: "#{@workflow.name} deleted.", status: :see_other
  end

  def publish
    version = @workflow.publish!
    redirect_to edit_workflow_path(@workflow), notice: "Version #{version.number} is live. People already in the workflow finish on the version they started."
  rescue ArgumentError => error
    redirect_to edit_workflow_path(@workflow), alert: "Can't publish yet: #{error.message}"
  end

  def pause
    @workflow.pause!
    redirect_back_or_to @workflow, notice: "Paused. People stop at their next step until you resume."
  end

  def resume
    @workflow.resume!
    redirect_back_or_to @workflow, notice: "Resumed."
  end

  def stop_runs
    count = @workflow.runs.in_flight.count
    @workflow.stop_all_runs!
    redirect_to @workflow, notice: "Stopped #{ActionController::Base.helpers.pluralize(count, "run")}.", status: :see_other
  end

  private
    def set_workflow
      @workflow = authorize Workflow.find(params.expect(:id))
    end

    def workflow_params = params.expect(workflow: %i[ name description allow_reentry ])
end
