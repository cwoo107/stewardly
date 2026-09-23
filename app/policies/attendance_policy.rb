# Headless: attendance screens. Recording (ushers) and reporting are separate permissions.
class AttendancePolicy < ApplicationPolicy
  def show? = can?(:view_attendance)
  def record? = can?(:record_attendance)
  def accuracy? = show?
end
