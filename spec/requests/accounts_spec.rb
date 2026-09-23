require "rails_helper"

RSpec.describe "Member accounts" do
  include ActiveJob::TestHelper

  let!(:member_role) { create(:role, key: "member", name: "Member") }
  let(:person) { create(:person, first_name: "Ada", email: "ada@example.com") }

  it "lets staff with manage_users invite someone, and audits it" do
    sign_in_as(create(:user, :church_admin))
    expect { post person_account_invitation_path(person) }.to have_enqueued_mail(AccountMailer, :setup)
    expect(AuditEvent.last.action).to eq("account.invited")
  end

  it "won't invite without manage_users" do
    sign_in_as(create(:user, :staff))
    post person_account_invitation_path(person)
    expect(response).to have_http_status(:forbidden)
  end

  describe "self-claim" do
    before { on_church(church) }

    it "emails a link only to a known person without a login, but always says the same thing" do
      person
      expect { post account_setup_path, params: { email: "ADA@example.com" } }.to have_enqueued_mail(AccountMailer, :setup)
      expect(flash[:notice]).to include("If we know that email")

      expect { post account_setup_path, params: { email: "stranger@example.com" } }.not_to have_enqueued_mail
      expect(flash[:notice]).to include("If we know that email")
    end

    it "sets a password from the link and signs in to the member area" do
      token = person.generate_token_for(:account_setup)
      get edit_account_setup_path(token:)
      expect(response.body).to include("Welcome, Ada")

      patch account_setup_path(token:), params: { password: "a-long-password", password_confirmation: "a-long-password" }
      expect(response).to redirect_to(member_root_path)
      user = person.reload.user
      expect(user.roles).to contain_exactly(member_role)
      expect(user.email_address).to eq("ada@example.com")

      get edit_account_setup_path(token:) # used once: the account exists now
      expect(response).to redirect_to(new_account_setup_path)
    end

    it "rejects expired and tampered links" do
      token = person.generate_token_for(:account_setup)
      travel 8.days do
        get edit_account_setup_path(token:)
        expect(response).to redirect_to(new_account_setup_path)
      end
      get edit_account_setup_path(token: "#{token}x")
      expect(response).to redirect_to(new_account_setup_path)
    end
  end
end
