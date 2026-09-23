class MinistryLeadershipPolicy < ApplicationPolicy
  def create? = can?(:manage_ministries)
  def destroy? = can?(:manage_ministries)
end
