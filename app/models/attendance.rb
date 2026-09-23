# One person checked in at a service. first_time is set when it's their first
# check-in ever at this church.
class Attendance < ApplicationRecord
  belongs_to :service_occurrence
  belongs_to :person
  belongs_to :checked_in_by, class_name: "User", optional: true
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  validates :person_id, uniqueness: { scope: :service_occurrence_id, message: "is already checked in" }

  before_validation { self.checked_in_at ||= Time.current }
  before_create { self.first_time = !Attendance.exists?(person_id:) }
end
