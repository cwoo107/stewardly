class PrayerAssignmentPolicy < ApplicationPolicy
  def create? = can?(:manage_prayer_requests)
  def destroy? = create?
end
