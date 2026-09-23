require_relative "church_preview"

class EnrollmentMailerPreview < ActionMailer::Preview
  include ChurchPreview

  %i[ confirmed waitlisted promoted ].each do |kind|
    define_method(kind) { within_church { EnrollmentMailer.public_send(kind, Enrollment.first) } }
  end
end
