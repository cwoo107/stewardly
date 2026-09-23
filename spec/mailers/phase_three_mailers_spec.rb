require "rails_helper"

RSpec.describe "Phase 3 mailers" do
  before { church.update!(name: "Grace", contact_email: "office@grace.test") }

  it "asks a volunteer to serve, with a link on the church's subdomain" do
    assignment = create(:assignment, person: create(:person, email: "vol@example.com"))
    mail = AssignmentMailer.request_to_serve(assignment)

    expect(mail.to).to eq([ "vol@example.com" ])
    expect(mail[:from].display_names).to eq([ "Grace" ])
    expect(mail.reply_to).to eq([ "office@grace.test" ])
    expect(mail.body.encoded).to include("http://#{church.host}/respond/#{assignment.response_token}")
  end

  it "sends nothing to people without an email" do
    assignment = create(:assignment, person: create(:person, email: nil))
    expect(AssignmentMailer.reminder(assignment).message).to be_a(ActionMailer::Base::NullMail)
  end

  it "tells ministry leaders about a decline, falling back to the church office" do
    assignment = create(:assignment)
    expect(AssignmentMailer.declined(assignment).to).to eq([ "office@grace.test" ])

    leader = create(:user)
    create(:ministry_leadership, ministry: assignment.team.ministry, user: leader)
    expect(AssignmentMailer.declined(assignment.reload).to).to eq([ leader.email_address ])
  end

  it "links registration emails to the manage page" do
    registration = create(:registration)
    expect(RegistrationMailer.confirmed(registration).body.encoded).to include("/registrations/#{registration.manage_token}")
  end

  it "sends an account setup link that works" do
    person = create(:person, email: "new@example.com")
    body = AccountMailer.setup(person).body.encoded
    token = body[%r{account_setup/edit\?token=([^"\s]+)}, 1]
    expect(Person.find_by_token_for(:account_setup, CGI.unescape(token))).to eq(person)
  end
end
