# Headless: the people-and-groups map. Household precision is decided by Map::Layers.
class MapPolicy < ApplicationPolicy
  def show? = can?(:view_people)
end
