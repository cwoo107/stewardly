class WebhookEventPolicy < ApplicationPolicy
  def index? = can?(:manage_integrations)
  def show? = can?(:manage_integrations)
  def replay? = can?(:manage_integrations)

  class Scope < Scope
    def resolve
      can?(:manage_integrations) ? scope.all : scope.none
    end
  end
end
