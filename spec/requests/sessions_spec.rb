require "rails_helper"

RSpec.describe "Sessions" do
  let(:user) { create(:user, :member) }

  it "signs in with valid credentials and sets the session's church" do
    sign_in_as(user)
    expect(user.sessions.sole.church).to eq(church)
  end

  it "rejects a wrong password" do
    on_church(church)
    post session_path, params: { email_address: user.email_address, password: "wrong" }
    expect(response).to redirect_to(new_session_path)
  end

  it "signs out" do
    sign_in_as(user)
    delete session_path
    expect(response).to redirect_to(new_session_path)
    expect(Session.count).to eq(0)

    get root_path
    expect(response).to redirect_to(new_session_url)
  end
end
