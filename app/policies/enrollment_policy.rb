class EnrollmentPolicy < ApplicationPolicy
  def create? = CourseOfferingPolicy.new(user, record.course_offering).take_attendance?
  def update? = create?
  def withdraw_own? = user.present? && record.person_id == user.person_id
end
