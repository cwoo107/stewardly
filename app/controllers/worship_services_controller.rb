class WorshipServicesController < ApplicationController
  before_action :set_service, only: %i[ edit update destroy ]

  def index
    authorize WorshipService
    @services = policy_scope(WorshipService).ordered.includes(:campus, position_needs: { position: :team })
  end

  def new
    @service = authorize WorshipService.new(day_of_week: 0, start_time: "09:00", campus: Campus.default)
  end

  def create
    @service = authorize WorshipService.new(service_params)
    if @service.save
      redirect_to worship_services_path, notice: "#{@service.name} added."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    @positions = Position.joins(:team).includes(:team).order("teams.name", :name)
  end

  def update
    if @service.update(service_params)
      redirect_to worship_services_path, notice: "Saved."
    else
      @positions = Position.joins(:team).includes(:team).order("teams.name", :name)
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @service.destroy!
    redirect_to worship_services_path, notice: "Service removed.", status: :see_other
  end

  private
    def set_service
      @service = authorize policy_scope(WorshipService).includes(position_needs: :position).find(params.expect(:id))
    end

    def service_params
      params.expect(worship_service: %i[ name campus_id day_of_week start_time duration_minutes active ])
    end
end
