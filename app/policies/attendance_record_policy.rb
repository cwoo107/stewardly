# Individual check-ins.
class AttendanceRecordPolicy < ApplicationPolicy
  def create? = can?(:record_attendance)
  def destroy? = create?
end
