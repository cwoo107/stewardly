# Church-wide manage_ministries covers every ministry; a MinistryLeadership covers one.
class MinistryPolicy < ApplicationPolicy
  def index? = see_all? || user&.leads_any_ministry?
  def show? = see_all? || leads?
  def create? = can?(:manage_ministries)
  def update? = can?(:manage_ministries) || leads?
  def destroy? = can?(:manage_ministries)
  def manage_leaders? = can?(:manage_ministries)

  private
    def see_all? = can?(:view_people) || can?(:manage_ministries)
    def leads? = user.present? && user.leads?(record)

  class Scope < Scope
    def resolve
      return scope.all if can?(:view_people) || can?(:manage_ministries)
      return scope.none unless user

      scope.where(id: user.led_ministry_ids)
    end
  end
end
