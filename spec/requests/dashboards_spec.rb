require "rails_helper"

RSpec.describe "Dashboard" do
  it "sends members to the member area" do
    sign_in_as(create(:user, :member))
    get root_path
    expect(response).to redirect_to(member_root_path)
  end

  it "welcomes staff" do
    user = create(:user, :staff)
    sign_in_as(user)
    get root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Welcome, #{user.person.first_name}")
  end

  it "only shows navigation the user is permitted to use" do
    sign_in_as(create(:user, :care_team))
    get root_path
    expect(response.body).not_to include(users_path)
    expect(response.body).not_to include(edit_church_settings_path)
  end
end
