class TeamMembershipsController < ApplicationController
  before_action :set_team

  def create
    membership = authorize @team.team_memberships.new(person: Person.unmerged.find(params.expect(team_membership: [ :person_id ])[:person_id]))
    if membership.save
      redirect_to @team, notice: "#{membership.person.name} joined #{@team.name}.", status: :see_other
    else
      redirect_to @team, alert: membership.errors.full_messages.to_sentence, status: :see_other
    end
  end

  # Scheduling setting: at most N times a month (blank = no limit).
  def update
    membership = authorize @team.team_memberships.find(params.expect(:id))
    membership.update!(max_per_month: params.dig(:team_membership, :max_per_month).presence)
    redirect_to team_path(@team, anchor: "scheduling"), notice: "Saved.", status: :see_other
  end

  def destroy
    membership = authorize @team.team_memberships.find(params.expect(:id))
    membership.destroy!
    redirect_to @team, notice: "#{membership.person.name} left #{@team.name}.", status: :see_other
  end

  private
    def set_team
      @team = Team.find(params.expect(:team_id))
    end
end
