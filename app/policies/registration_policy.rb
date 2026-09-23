class RegistrationPolicy < ApplicationPolicy
  def index? = EventPolicy.new(user, record.event).update?
  def create? = index?
  def update? = index?
  # Members cancel their own registrations.
  def cancel_own? = user.present? && record.person_id == user.person_id
end
