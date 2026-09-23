class EventPolicy < ApplicationPolicy
  def index? = can?(:manage_events) || can?(:view_people) || user&.leads_any_ministry?
  def show? = manage? || can?(:view_people)
  def create? = can?(:manage_events) || (record.is_a?(Event) && leads?)
  def new? = can?(:manage_events) || user&.leads_any_ministry?
  def update? = manage?
  def publish? = manage?
  def cancel? = manage?
  def destroy? = manage? && record.registrations.none?
  def check_in? = manage?

  private
    def manage? = can?(:manage_events) || leads?
    def leads? = user.present? && user.leads?(record.ministry)

  class Scope < Scope
    def resolve
      return scope.all if can?(:manage_events) || can?(:view_people)
      return scope.none unless user

      scope.where(ministry_id: user.led_ministry_ids)
    end
  end
end
