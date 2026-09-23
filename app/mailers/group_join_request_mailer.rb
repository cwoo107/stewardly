class GroupJoinRequestMailer < ApplicationMailer
  # To whoever can approve: the group's leaders who can sign in, and its ministry's leaders.
  def received(join_request)
    @join_request = join_request
    group = join_request.group
    leaders = User.where(person_id: group.leaders.select(:id)).pluck(:email_address)
    leaders += group.ministry.leaders.pluck(:email_address) if group.ministry
    recipients = leaders.uniq.presence || [ church.contact_email ].compact_blank
    return if recipients.empty?

    mail(to: recipients, subject: "#{join_request.person.name} would like to join #{group.name}")
  end

  def decided(join_request)
    @join_request = join_request
    mail_person(join_request.person, subject: join_request.approved? ? "Welcome to #{join_request.group.name}" : "About #{join_request.group.name}")
  end
end
