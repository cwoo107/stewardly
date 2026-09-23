# Giving managers manage every fund; the benevolence team only its own (benevolence) funds.
class FundPolicy < ApplicationPolicy
  def index? = can?(:view_giving) || can?(:manage_benevolence)
  def create? = can?(:manage_giving) || can?(:manage_benevolence)
  def update? = can?(:manage_giving) || (can?(:manage_benevolence) && (record.is_a?(Class) || record.benevolence?))
  def change_benevolence_flag? = can?(:manage_giving)

  class Scope < Scope
    def resolve
      return scope.all if can?(:view_giving) || can?(:manage_giving)
      return scope.for_benevolence if can?(:manage_benevolence)

      scope.none
    end
  end
end
