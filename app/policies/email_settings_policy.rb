# Email settings: sending address, postal address, and DNS. Provider credentials are
# IntegrationPolicy (manage_integrations).
class EmailSettingsPolicy < ApplicationPolicy
  def show? = can?(:manage_email) || can?(:manage_integrations)
  def update? = can?(:manage_email)
end
