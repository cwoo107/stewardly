# Posting needs manage_social; connecting or removing accounts needs manage_integrations.
class SocialAccountPolicy < ApplicationPolicy
  def index? = can?(:manage_social) || can?(:manage_integrations)
  def connect? = can?(:manage_integrations)
  def check? = can?(:manage_integrations)
  def destroy? = can?(:manage_integrations)

  class Scope < Scope
    def resolve
      can?(:manage_social) || can?(:manage_integrations) ? scope.all : scope.none
    end
  end
end
