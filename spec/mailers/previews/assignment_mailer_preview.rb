require_relative "church_preview"

class AssignmentMailerPreview < ActionMailer::Preview
  include ChurchPreview

  def request_to_serve = within_church { AssignmentMailer.request_to_serve(Assignment.first) }
  def reminder = within_church { AssignmentMailer.reminder(Assignment.accepted.first || Assignment.first) }
  def declined = within_church { AssignmentMailer.declined(Assignment.first) }
end
