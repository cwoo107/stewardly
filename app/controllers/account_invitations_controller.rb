# "Give member area access": emails the person a link to set a password.
class AccountInvitationsController < ApplicationController
  def create
    person = authorize policy_scope(Person).find(params.expect(:person_id)), :invite?
    AccountMailer.setup(person).deliver_later
    AuditEvent.record!(action: "account.invited", auditable: person, metadata: { email: person.email })
    redirect_to person, notice: "Sent #{person.first_name} a link to set up their account.", status: :see_other
  end
end
