# Whether an enrolled person was at a course session. (Sunday check-ins are Phase 4's Attendance.)
class SessionAttendance < ApplicationRecord
  belongs_to :course_session
  belongs_to :enrollment
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  validates :enrollment_id, uniqueness: { scope: :course_session_id }
end
