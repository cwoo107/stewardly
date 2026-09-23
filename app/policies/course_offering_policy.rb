# Offerings follow their course; the offering's leader may also run the roster and attendance.
class CourseOfferingPolicy < ApplicationPolicy
  def show? = CoursePolicy.new(user, record.course).show? || leader?
  def create? = CoursePolicy.new(user, record.course).update?
  def update? = create?
  def destroy? = create? && record.enrollments.none?
  def take_attendance? = create? || leader?

  private
    def leader? = user.present? && record.leader_id.present? && record.leader_id == user.person_id
end
