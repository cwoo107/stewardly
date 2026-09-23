# Headless: the duplicate review queue and dismissing a suggested pair.
class DuplicatePolicy < ApplicationPolicy
  def index? = can?(:manage_people)
  def dismiss? = can?(:manage_people)
end
