class AssignmentPolicy < ApplicationPolicy
  def create? = schedule?
  def update? = schedule?
  def destroy? = schedule?
  # Volunteers answer their own requests.
  def respond? = user.present? && record.person_id == user.person_id

  private
    def schedule? = TeamSchedulePolicy.new(user, record.position.team).show?
end
