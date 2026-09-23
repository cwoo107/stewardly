class CampusPolicy < ApplicationPolicy
  def index? = can?(:manage_church_settings)
  def create? = can?(:manage_church_settings)
  def update? = can?(:manage_church_settings)
  def destroy? = can?(:manage_church_settings) && !record.is_default?

  class Scope < Scope
    def resolve
      can?(:manage_church_settings) ? scope.all : scope.none
    end
  end
end
