require_relative "church_preview"

class RegistrationMailerPreview < ActionMailer::Preview
  include ChurchPreview

  %i[ confirmed waitlisted promoted reminder ].each do |kind|
    define_method(kind) { within_church { RegistrationMailer.public_send(kind, Registration.first) } }
  end
end
