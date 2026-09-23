class CampaignPolicy < ApplicationPolicy
  def index? = can?(:manage_email)
  def show? = can?(:manage_email)
  def create? = can?(:manage_email)
  def update? = can?(:manage_email) && record_editable?
  def schedule? = update?
  def deliver? = update?
  def cancel? = can?(:manage_email) && (record.is_a?(Class) || record.scheduled?)
  def destroy? = can?(:manage_email) && (record.is_a?(Class) || record.draft? || record.cancelled?)

  private
    def record_editable? = record.is_a?(Class) || record.editable?

  class Scope < Scope
    def resolve
      can?(:manage_email) ? scope.all : scope.none
    end
  end
end
