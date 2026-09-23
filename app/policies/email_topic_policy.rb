class EmailTopicPolicy < ApplicationPolicy
  def index? = can?(:manage_email)
  def show? = can?(:manage_email)
  def create? = can?(:manage_email)
  def update? = can?(:manage_email)
  def destroy? = can?(:manage_email)

  class Scope < Scope
    def resolve
      can?(:manage_email) ? scope.all : scope.none
    end
  end
end
