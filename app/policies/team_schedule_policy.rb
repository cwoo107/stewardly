# Building a team's schedule: manage_schedules for every team, or leading the team's ministry.
class TeamSchedulePolicy < ApplicationPolicy
  def show? = can?(:manage_schedules) || (user.present? && user.leads?(record.ministry))
  def auto_fill? = show?
  def send_requests? = show?
end
