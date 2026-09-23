require "rails_helper"

RSpec.describe "Map" do
  before do
    create(:household, :with_location, name: "The Secret household", latitude: 36.16271, longitude: -86.78164)
    create(:group, :with_location, name: "Downtown Study", latitude: 36.2, longitude: -86.7)
  end

  it "shows exact household points to staff" do
    sign_in_as(create(:user, :staff))
    get map_path
    expect(response.body).to include("The Secret household", "36.16271", "Downtown Study")
  end

  it "never sends exact coordinates or names to users without view_precise_locations" do
    sign_in_as(create(:user, :care_team))
    get map_path
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("The Secret household")
    expect(response.body).not_to include("36.16271")
    expect(response.body).to include("approximately")
  end

  it "shows the coverage gap" do
    sign_in_as(create(:user, :staff))
    get map_path(coverage_gap: "1")
    expect(response.body).to include("The Secret household") # ~6 miles from the only group
  end

  it "is forbidden to members" do
    sign_in_as(create(:user, :member))
    get map_path
    expect(response).to have_http_status(:forbidden)
  end
end
