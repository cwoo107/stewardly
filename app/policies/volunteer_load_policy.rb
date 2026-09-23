# Headless: the volunteer load view (all teams with manage_schedules, a leader's own teams otherwise)
# and its thresholds (manage_pathways).
class VolunteerLoadPolicy < ApplicationPolicy
  def show? = can?(:manage_schedules) || user&.leads_any_ministry?
  def update? = can?(:manage_pathways)
end
