require "rails_helper"

RSpec.describe "Password resets" do
  include ActionMailer::TestHelper

  let(:user) { create(:user) }

  it "emails a reset link on the church's own subdomain" do
    on_church(church)

    perform_enqueued_jobs do
      post passwords_path, params: { email_address: user.email_address }
    end

    mail = ActionMailer::Base.deliveries.sole
    expect(mail.to).to eq([ user.email_address ])
    expect(mail.subject).to include(church.name)
    expect(mail.text_part.body.to_s).to include("http://#{church.host}/passwords/")
  end

  it "doesn't send mail for another church's user" do
    other_church = create(:church, subdomain: "elsewhere")
    on_church(other_church)

    expect { post passwords_path, params: { email_address: user.email_address } }.not_to have_enqueued_mail
  end

  it "resets the password with a valid token" do
    on_church(church)
    put password_path(user.password_reset_token), params: { password: "new-password", password_confirmation: "new-password" }

    expect(response).to redirect_to(new_session_path)
    expect(user.reload.authenticate("new-password")).to be_truthy
  end
end
