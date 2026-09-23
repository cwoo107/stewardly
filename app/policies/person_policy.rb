class PersonPolicy < ApplicationPolicy
  def index? = can?(:view_people)
  def show? = can?(:view_people)
  def create? = can?(:manage_people)
  def update? = can?(:manage_people)
  def destroy? = can?(:manage_people)
  def merge? = can?(:manage_people)
  # Emails a member area setup link (only to people with an email and no login yet).
  def invite? = can?(:manage_users) && record.email.present? && record.user.nil?
  # Name lookups for adding members; ministry leaders need this without view_people.
  def search? = can?(:view_people) || user&.leads_any_ministry?

  class Scope < Scope
    def resolve
      can?(:view_people) ? scope.unmerged : scope.none
    end
  end
end
