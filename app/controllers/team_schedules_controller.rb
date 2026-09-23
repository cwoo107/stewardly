# The drag-and-drop schedule board for one team and a date range (default: next 5 weeks).
class TeamSchedulesController < ApplicationController
  WEEKS = 5

  before_action :set_team

  def show
    @board = Scheduling::Board.new(team: @team, range:)
    @memberships = @team.team_memberships.includes(:person).sort_by { |m| [ m.person.last_name, m.person.first_name ] }
    @awaiting_request = Assignment.awaiting_request.where(position: @team.positions, local_date: range).count
  end

  def auto_fill
    count = Scheduling::AutoFill.new(team: @team, range:, assigned_by: Current.user).fill!
    redirect_to team_schedule_path(@team, from: range.first), notice: "Suggested #{helpers.pluralize(count, "volunteer")}. Review, then send requests.", status: :see_other
  end

  # Emails every pending assignment in the range that hasn't been asked yet.
  def send_requests
    assignments = Assignment.awaiting_request.where(position: @team.positions, local_date: range).includes(:person, :position, :schedulable)
    assignments.each do |assignment|
      AssignmentMailer.request_to_serve(assignment).deliver_later
      assignment.mark_requested!
    end
    redirect_to team_schedule_path(@team, from: range.first), notice: "Sent #{helpers.pluralize(assignments.size, "request")}.", status: :see_other
  end

  private
    def set_team
      @team = Team.includes(:ministry, positions: :position_qualifications).find(params.expect(:team_id))
      authorize @team, :show?, policy_class: TeamSchedulePolicy
    end

    def range
      from = Date.parse(params[:from].to_s) rescue Current.church.today
      from.beginning_of_week(:sunday)..(from.beginning_of_week(:sunday) + WEEKS.weeks - 1.day)
    end
end
