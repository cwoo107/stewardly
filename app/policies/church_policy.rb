class ChurchPolicy < ApplicationPolicy
  def update? = can?(:manage_church_settings) && record.id == user.church_id
end
