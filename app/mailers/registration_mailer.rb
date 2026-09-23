class RegistrationMailer < ApplicationMailer
  def confirmed(registration) = registration_mail(registration, "You're registered for #{registration.event.title}")
  def waitlisted(registration) = registration_mail(registration, "You're on the waitlist for #{registration.event.title}")
  def promoted(registration) = registration_mail(registration, "A spot opened up: you're registered for #{registration.event.title}")
  def reminder(registration) = registration_mail(registration, "See you tomorrow at #{registration.event.title}")

  private
    def registration_mail(registration, subject)
      @registration = registration
      @occurrence = registration.event_occurrence
      mail_person(registration.person, subject:)
    end
end
