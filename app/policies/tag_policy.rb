class TagPolicy < ApplicationPolicy
  def index? = can?(:manage_people)
  def show? = can?(:manage_people)
  def create? = can?(:manage_people)
  def update? = can?(:manage_people)
  def destroy? = can?(:manage_people)

  class Scope < Scope
    def resolve
      can?(:manage_people) ? scope.all : scope.none
    end
  end
end
