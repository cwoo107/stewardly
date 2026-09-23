# manage_tasks sees everything; anyone else sees and updates only tasks they own.
class TaskPolicy < ApplicationPolicy
  def index? = can?(:manage_tasks) || (user.present? && user.owned_tasks.exists?)
  def show? = can?(:manage_tasks) || owner?
  def create? = can?(:manage_tasks)
  def update? = can?(:manage_tasks) || owner?
  def move? = update?
  def destroy? = can?(:manage_tasks)

  private
    def owner? = user.present? && record.owner_id == user.id

  class Scope < Scope
    def resolve
      return scope.all if can?(:manage_tasks)
      return scope.none unless user

      scope.where(owner: user)
    end
  end
end
