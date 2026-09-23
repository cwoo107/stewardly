class AssignmentMailer < ApplicationMailer
  # Asks a volunteer to serve; the links open a page with Accept and Decline buttons.
  def request_to_serve(assignment)
    @assignment = assignment
    mail_person(assignment.person, subject: "Can you serve as #{assignment.position.name} on #{I18n.l(assignment.local_date, format: :long)}?")
  end

  def reminder(assignment)
    @assignment = assignment
    mail_person(assignment.person, subject: "Reminder: you're serving #{I18n.l(assignment.local_date, format: :long)}")
  end

  # Tells the team's ministry leaders someone declined so they can find a replacement.
  def declined(assignment)
    @assignment = assignment
    leaders = assignment.team.ministry.leaders.includes(:person).map(&:email_address)
    recipients = leaders.presence || [ church.contact_email ].compact_blank
    return if recipients.empty?

    mail(to: recipients, subject: "#{assignment.person.name} can't serve on #{I18n.l(assignment.local_date, format: :long)}")
  end
end
