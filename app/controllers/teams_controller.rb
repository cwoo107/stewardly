class TeamsController < ApplicationController
  before_action :set_team, only: %i[ show edit update destroy ]

  def show
    @memberships = @team.team_memberships.includes(:person).sort_by { |m| [ m.leader? ? 0 : 1, m.person.last_name ] }
    @positions = @team.positions.alphabetical.includes(position_qualifications: :person)
    @loads = Volunteering::LoadAssessment.new(people: @memberships.map(&:person_id), church: Current.church) if TeamSchedulePolicy.new(Current.user, @team).show?
  end

  def new
    @team = authorize Team.new(ministry_id: params[:ministry_id])
  end

  def create
    @team = authorize Team.new(team_params)
    if @team.save
      redirect_to @team, notice: "Team added."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    @team.assign_attributes(team_params)
    authorize @team
    if @team.save
      redirect_to @team, notice: "Saved."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @team.destroy!
    redirect_to @team.ministry, notice: "Team deleted.", status: :see_other
  end

  private
    def set_team
      @team = authorize Team.includes(:ministry).find(params.expect(:id))
    end

    def team_params
      params.expect(team: %i[ name description ministry_id ])
    end
end
