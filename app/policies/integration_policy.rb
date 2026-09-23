class IntegrationPolicy < ApplicationPolicy
  def index? = can?(:manage_integrations)
  def create? = can?(:manage_integrations)
  def update? = can?(:manage_integrations)
  def destroy? = can?(:manage_integrations)
  def sync? = can?(:manage_integrations) && record.try(:category) == "email_audience_sync"
end
