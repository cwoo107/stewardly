class RolePolicy < ApplicationPolicy
  def index? = can?(:manage_users)
  def show? = can?(:manage_users)

  class Scope < Scope
    def resolve
      can?(:manage_users) ? scope.all : scope.none
    end
  end
end
