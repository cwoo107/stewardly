class EnrollmentMailer < ApplicationMailer
  def confirmed(enrollment) = enrollment_mail(enrollment, "You're enrolled in #{enrollment.course_offering.name}")
  def waitlisted(enrollment) = enrollment_mail(enrollment, "You're on the waitlist for #{enrollment.course_offering.name}")
  def promoted(enrollment) = enrollment_mail(enrollment, "A spot opened up in #{enrollment.course_offering.name}")

  private
    def enrollment_mail(enrollment, subject)
      @enrollment = enrollment
      @offering = enrollment.course_offering
      mail_person(enrollment.person, subject:)
    end
end
