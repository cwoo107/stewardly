require "rails_helper"

RSpec.describe "Platform churches" do
  let(:platform_admin) { create(:platform_admin) }

  it "requires a platform admin" do
    on_platform
    get platform_churches_path
    expect(response).to redirect_to(new_platform_session_path)
  end

  context "as a platform admin" do
    before { sign_in_as_platform_admin(platform_admin) }

    it "lists churches" do
      church
      get platform_churches_path
      expect(response.body).to include(church.name)
    end

    it "provisions a church with its first admin" do
      post platform_churches_path, params: {
        church: { name: "New Life", subdomain: "newlife", time_zone: "Pacific Time (US & Canada)" },
        admin: { first_name: "Ada", last_name: "Park", email_address: "ada@newlife.test", password: "password" }
      }

      expect(response).to redirect_to(platform_churches_path)
      new_life = Church.find_by!(subdomain: "newlife")
      ActsAsTenant.with_tenant(new_life) { expect(User.sole).to be_church_admin }
    end

    it "re-renders the form with errors" do
      post platform_churches_path, params: {
        church: { name: "New Life", subdomain: "www", time_zone: "Pacific Time (US & Canada)" },
        admin: { first_name: "Ada", last_name: "Park", email_address: "ada@newlife.test", password: "password" }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Subdomain is reserved")
    end
  end
end
