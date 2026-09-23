class PathwayStagePolicy < ApplicationPolicy
  def create? = can?(:manage_pathways)
  def update? = create?
  def move? = create?
  def preview? = create?
  def destroy? = create? && record.placements.none? && record.pathway.stages.size > 2
end
