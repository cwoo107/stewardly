class MessageDraftPolicy < ApplicationPolicy
  def index? = can?(:approve_messages)
  def update? = can?(:approve_messages) && record.pending?
  def reject? = update?

  class Scope < Scope
    def resolve
      can?(:approve_messages) ? scope.all : scope.none
    end
  end
end
