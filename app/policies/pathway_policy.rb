class PathwayPolicy < ApplicationPolicy
  def show? = can?(:view_people)
  def update? = can?(:manage_pathways)
end
