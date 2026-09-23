# Enrolls a person in an offering, or waitlists them when it's full. Re-enrolling
# after withdrawing reuses the same record. The offering is locked while booking.
class Enrollment::Booking
  Result = Data.define(:enrollment, :created)

  def initialize(offering:, person:)
    @offering = offering
    @person = person
  end

  def book!
    result = @offering.with_lock do
      enrollment = @offering.enrollments.find_or_initialize_by(person: @person)
      next Result.new(enrollment, false) if enrollment.persisted? && !enrollment.withdrawn?

      enrollment.update!(status: @offering.fits?(1) ? :enrolled : :waitlisted, withdrawn_at: nil)
      Result.new(enrollment, true)
    end

    (result.enrollment.enrolled? ? EnrollmentMailer.confirmed(result.enrollment) : EnrollmentMailer.waitlisted(result.enrollment)).deliver_later if result.created
    result
  end
end
