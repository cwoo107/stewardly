# Benevolence is strictly permissioned: the Benevolence team role, or church admins.
class BenevolenceCasePolicy < ApplicationPolicy
  def index? = can?(:view_benevolence)
  def show? = can?(:view_benevolence)
  def create? = can?(:manage_benevolence)
  def update? = can?(:manage_benevolence) && record_open?
  def note? = can?(:manage_benevolence)
  def disburse? = can?(:manage_benevolence)
  def decide? = can?(:approve_benevolence)
  def report? = can?(:view_benevolence)

  private
    def record_open? = record.is_a?(Class) || record.open?

  class Scope < Scope
    def resolve
      can?(:view_benevolence) ? scope.all : scope.none
    end
  end
end
