require "rails_helper"

RSpec.describe "Households" do
  include ActiveJob::TestHelper

  let(:staff) { create(:user, :staff) }

  before { sign_in_as(staff) }

  it "creates a household and geocodes it in the background" do
    expect {
      post households_path, params: { household: { name: "The Parks", address_line1: "1 Elm St", city: "Nashville", postal_code: "37203" } }
    }.to have_enqueued_job(GeocodeJob)
    expect(response).to redirect_to(Household.last)
  end

  it "shows nearest groups with distances" do
    household = create(:household, :with_location, latitude: 36.1627, longitude: -86.7816)
    create(:group, :with_location, name: "Nearby Group", latitude: 36.17, longitude: -86.78)

    get household_path(household)

    expect(response.body).to include("Nearby Group", "0.5 mi")
  end

  it "searches" do
    create(:household, name: "The Parks")
    create(:household, name: "The Lees")
    get households_path(q: "park")
    expect(response.body).to include("The Parks")
    expect(response.body).not_to include("The Lees")
  end
end
