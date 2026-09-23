class TasksController < ApplicationController
  before_action :set_task, only: %i[ show edit update destroy move ]

  # Board (default) or list view, with the same filters.
  def index
    authorize Task
    @view = params[:view] == "list" ? "list" : "board"
    tasks = filtered(policy_scope(Task)).includes(:project, owner: :person)

    if @view == "board"
      tasks = tasks.on_board.ordered
      # Low-priority ideas stay parked out of sight unless asked for (NOT (idea AND low)).
      tasks = tasks.where.not(status: "idea", priority: "low") unless params[:show_low_ideas] == "1"
      @columns = Task::BOARD_STATUSES.index_with { |status| tasks.select { |task| task.status == status } }
      @hidden_low_ideas = policy_scope(Task).idea.priority_low.count unless params[:show_low_ideas] == "1"
    else
      @pagy, @tasks = pagy(tasks.order(Arel.sql("due_on IS NULL, due_on"), :position))
    end
  end

  def show
  end

  def new
    @task = authorize Task.new(status: params[:status].presence_in(Task.statuses.keys) || "todo", project_id: params[:project_id])
  end

  def create
    @task = authorize Task.new(task_params.merge(created_by: Current.user))
    if @task.save
      redirect_to tasks_path, notice: "Task added."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @task.update(permitted_update_params)
      redirect_to tasks_path(view: params[:view]), notice: "Task saved."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @task.destroy!
    redirect_to tasks_path, notice: "Task deleted.", status: :see_other
  end

  # Drag and drop on the board.
  def move
    @task.move_to(status: params.expect(:status).presence_in(Task.statuses.keys) || @task.status, position: params.expect(:position))
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to tasks_path, status: :see_other }
    end
  end

  private
    def set_task
      @task = authorize policy_scope(Task).find(params.expect(:id))
    end

    def filtered(tasks)
      tasks = tasks.where(owner_id: params[:owner_id] == "me" ? Current.user.id : params[:owner_id]) if params[:owner_id].present?
      tasks = tasks.where(project_id: params[:project_id]) if params[:project_id].present?
      tasks = tasks.where(priority: params[:priority]) if Task.priorities.key?(params[:priority])
      tasks = tasks.overdue(Current.church.today) if params[:overdue] == "1"
      tasks
    end

    def task_params
      params.expect(task: %i[ title notes status priority owner_id project_id due_on ])
    end

    # Owners without manage_tasks may update their own tasks, but not hand them to someone else.
    def permitted_update_params
      Current.user.can?(:manage_tasks) ? task_params : task_params.except(:owner_id, :project_id)
    end
end
