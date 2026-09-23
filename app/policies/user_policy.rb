class UserPolicy < ApplicationPolicy
  def index? = can?(:manage_users)
  def show? = can?(:manage_users)
  # Nobody deletes their own account here, which also protects the last church admin.
  def destroy? = can?(:manage_users) && record != user

  class Scope < Scope
    def resolve
      can?(:manage_users) ? scope.all : scope.where(id: user)
    end
  end
end
