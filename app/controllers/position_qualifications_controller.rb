class PositionQualificationsController < ApplicationController
  before_action :set_team

  def create
    qualification = authorize PositionQualification.new(position: @team.positions.find(params.dig(:position_qualification, :position_id)),
      person: Person.find(params.dig(:position_qualification, :person_id)))
    if qualification.save
      redirect_to team_schedule_settings_path, notice: "#{qualification.person.name} can serve as #{qualification.position.name}.", status: :see_other
    else
      redirect_to team_schedule_settings_path, alert: qualification.errors.full_messages.to_sentence, status: :see_other
    end
  end

  def destroy
    qualification = authorize PositionQualification.where(position: @team.positions).find(params.expect(:id))
    qualification.destroy!
    redirect_to team_schedule_settings_path, notice: "Removed.", status: :see_other
  end

  private
    def set_team
      @team = Team.find(params.expect(:team_id))
    end

    def team_schedule_settings_path = team_path(@team, anchor: "scheduling")
end
