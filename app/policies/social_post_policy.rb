class SocialPostPolicy < ApplicationPolicy
  def index? = can?(:manage_social)
  def show? = can?(:manage_social)
  def create? = can?(:manage_social)
  def update? = can?(:manage_social) && (record.is_a?(Class) || record.editable?)
  def destroy? = can?(:manage_social) && (record.is_a?(Class) || record.draft? || record.cancelled?)
  def schedule? = update?
  def publish_now? = update?
  def cancel? = can?(:manage_social) && (record.is_a?(Class) || record.scheduled?)
  def polish? = update?

  class Scope < Scope
    def resolve
      can?(:manage_social) ? scope.all : scope.none
    end
  end
end
