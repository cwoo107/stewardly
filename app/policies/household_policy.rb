class HouseholdPolicy < ApplicationPolicy
  def index? = can?(:view_people)
  def show? = can?(:view_people)
  def create? = can?(:manage_people)
  def update? = can?(:manage_people)
  def destroy? = can?(:manage_people)

  class Scope < Scope
    def resolve
      can?(:view_people) ? scope.all : scope.none
    end
  end
end
