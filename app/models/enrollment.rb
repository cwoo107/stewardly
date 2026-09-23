class Enrollment < ApplicationRecord
  include AffectsPathway

  belongs_to :course_offering
  belongs_to :person
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  has_many :session_attendances, dependent: :delete_all

  enum :status, { enrolled: "enrolled", waitlisted: "waitlisted", withdrawn: "withdrawn", completed: "completed" },
    default: :enrolled, validate: true

  validates :person_id, uniqueness: { scope: :course_offering_id, message: "is already enrolled" }

  scope :current, -> { where(status: %w[ enrolled waitlisted completed ]) }

  def complete!
    update!(status: :completed, completed_at: Time.current)
  end

  # Withdraws and hands the seat to the waitlist. Returns promoted enrollments.
  def withdraw!
    course_offering.with_lock do
      update!(status: :withdrawn, withdrawn_at: Time.current)
      course_offering.promote_waitlist!
    end.tap { |promoted| promoted.each { |enrollment| EnrollmentMailer.promoted(enrollment).deliver_later } }
  end

  def sessions_attended
    session_attendances.count(&:present)
  end
end
