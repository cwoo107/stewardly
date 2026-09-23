class PositionsController < ApplicationController
  before_action :set_team

  def create
    position = authorize @team.positions.new(params.expect(position: [ :name ]))
    if position.save
      redirect_to @team, notice: "Position added.", status: :see_other
    else
      redirect_to @team, alert: position.errors.full_messages.to_sentence, status: :see_other
    end
  end

  def destroy
    position = authorize @team.positions.find(params.expect(:id))
    position.destroy!
    redirect_to @team, notice: "Position removed.", status: :see_other
  end

  private
    def set_team
      @team = Team.find(params.expect(:team_id))
    end
end
