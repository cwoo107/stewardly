# Giving is read-only here and needs its own permission.
class DonationPolicy < ApplicationPolicy
  def index? = can?(:view_giving)
  def show? = can?(:view_giving)
  def export? = can?(:view_giving)
  def match? = can?(:manage_giving)

  class Scope < Scope
    def resolve
      can?(:view_giving) ? scope.all : scope.none
    end
  end
end
