class TeamPolicy < ApplicationPolicy
  def show? = can?(:view_people) || manage?
  def create? = manage?
  def update? = manage?
  def destroy? = manage?

  private
    def manage? = can?(:manage_ministries) || (user.present? && user.leads?(record.ministry))
end
