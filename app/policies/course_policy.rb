class CoursePolicy < ApplicationPolicy
  def index? = can?(:manage_courses) || can?(:view_people) || user&.leads_any_ministry?
  def show? = index?
  def create? = can?(:manage_courses) || (record.is_a?(Course) && leads?)
  def new? = can?(:manage_courses) || user&.leads_any_ministry?
  def update? = can?(:manage_courses) || leads?
  def destroy? = update? && record.offerings.none?

  private
    def leads? = user.present? && user.leads?(record.ministry)

  class Scope < Scope
    def resolve
      return scope.all if can?(:manage_courses) || can?(:view_people)
      return scope.none unless user

      scope.where(ministry_id: user.led_ministry_ids)
    end
  end
end
