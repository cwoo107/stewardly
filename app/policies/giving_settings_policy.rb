class GivingSettingsPolicy < ApplicationPolicy
  def show? = can?(:view_giving) || can?(:manage_integrations)
  def sync? = can?(:manage_integrations) || can?(:manage_giving)
end
