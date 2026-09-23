class AccountMailer < ApplicationMailer
  # Invitation from staff and self-claim both send this link.
  def setup(person)
    @person = person
    @token = person.generate_token_for(:account_setup)
    mail_person(person, subject: "Set up your #{church.name} account")
  end
end
