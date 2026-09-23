require "rails_helper"

RSpec.describe "Platform sessions" do
  let(:platform_admin) { create(:platform_admin) }

  it "signs platform admins in on the bare domain" do
    sign_in_as_platform_admin(platform_admin)
    expect(response).to redirect_to(platform_root_path)
    expect(platform_admin.platform_sessions.count).to eq(1)
  end

  it "rejects church users" do
    user = create(:user, :church_admin)
    on_platform
    post platform_session_path, params: { email_address: user.email_address, password: "password" }
    expect(response).to redirect_to(new_platform_session_path)
  end

  it "is not reachable from a church subdomain" do
    on_church(church)
    get "/churches"
    expect(response).to have_http_status(:not_found)
  end
end
