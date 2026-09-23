class ProjectsController < ApplicationController
  before_action :set_project, only: %i[ edit update destroy ]

  def index
    authorize Project
    @projects = policy_scope(Project).alphabetical.left_joins(:tasks).group(:id)
      .select("projects.*, count(tasks.id) FILTER (WHERE tasks.status <> 'done') AS open_tasks_count")
  end

  def new
    @project = authorize Project.new
  end

  def create
    @project = authorize Project.new(project_params)
    if @project.save
      redirect_to projects_path, notice: "Project added."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    attributes = project_params
    attributes = attributes.merge(archived_at: params[:archive] == "1" ? Time.current : nil) if params.key?(:archive)
    if @project.update(attributes)
      redirect_to projects_path, notice: "Project saved."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @project.destroy!
    redirect_to projects_path, notice: "Project deleted. Its tasks were kept.", status: :see_other
  end

  private
    def set_project
      @project = authorize policy_scope(Project).find(params.expect(:id))
    end

    def project_params
      params.fetch(:project, {}).permit(:name, :description)
    end
end
