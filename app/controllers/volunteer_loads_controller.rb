# Everyone on a team, with their volunteer load. Leaders see only their ministries' teams.
class VolunteerLoadsController < ApplicationController
  def show
    authorize :volunteer_load, :show?
    @teams = schedulable_teams.includes(:ministry).alphabetical
    @team = @teams.find { |team| team.id == params[:team_id].to_i }
    memberships = TeamMembership.where(team: @team || @teams).includes(:person, team: :ministry)
    people = memberships.map(&:person).uniq.sort_by { |person| [ person.last_name, person.first_name ] }
    loads = Volunteering::LoadAssessment.new(people:, church: Current.church)
    @rows = people.map { |person| [ person, memberships.select { |m| m.person_id == person.id }.map(&:team), loads.for(person, as_of: Current.church.today) ] }
    @level_counts = @rows.map(&:last).map(&:level).tally
    @level = params[:level].presence_in(Volunteering::LoadAssessment::LEVELS)
    @rows = @rows.select { |_, _, load| load.level == @level } if @level
  end

  # Thresholds (manage_pathways).
  def update
    authorize :volunteer_load, :update?
    thresholds = params.expect(thresholds: Volunteering::LoadAssessment::DEFAULT_THRESHOLDS.keys).to_h.transform_values { |value| Float(value, exception: false) }.compact
    Current.church.update!(volunteer_load_thresholds: thresholds)
    redirect_to volunteer_load_path, notice: "Thresholds saved.", status: :see_other
  end

  private
    def schedulable_teams
      Current.user.can?(:manage_schedules) ? Team.all : Team.where(ministry_id: Current.user.led_ministry_ids)
    end
end
