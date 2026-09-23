require "rails_helper"

RSpec.describe "Users" do
  let(:admin) { create(:user, :church_admin) }
  let!(:member) { create(:user, :member) }

  context "as a church admin" do
    before { sign_in_as(admin) }

    it "lists this church's users only" do
      outsider = ActsAsTenant.with_tenant(create(:church)) { create(:user) }

      get users_path
      expect(response.body).to include(member.email_address)
      expect(response.body).not_to include(outsider.email_address)
    end

    it "shows a user" do
      get user_path(member)
      expect(response).to have_http_status(:ok)
    end

    it "cannot load another church's user" do
      outsider = ActsAsTenant.with_tenant(create(:church)) { create(:user) }
      get user_path(outsider)
      expect(response).to have_http_status(:not_found)
    end

    it "removes a user's account, keeps their person, and audits it" do
      delete user_path(member)

      expect(response).to redirect_to(users_path)
      expect(User.exists?(member.id)).to be(false)
      expect(Person.exists?(member.person_id)).to be(true)
      expect(AuditEvent.where(action: "user.deleted").sole.actor).to eq(admin)
    end

    it "cannot remove their own account" do
      delete user_path(admin)
      expect(response).to have_http_status(:forbidden)
      expect(User.exists?(admin.id)).to be(true)
    end
  end

  it "is forbidden to members" do
    sign_in_as(member)
    get users_path
    expect(response).to have_http_status(:forbidden)
    get user_path(admin)
    expect(response).to have_http_status(:not_found).or have_http_status(:forbidden)
  end
end
