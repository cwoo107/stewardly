require "rails_helper"

RSpec.describe "Map", :js do
  # Tiles come from OpenStreetMap; keep specs off the network.
  before { page.driver.browser.url_blocklist = [ %r{tile\.openstreetmap\.org} ] }

  it "draws campuses, groups, and households with Leaflet" do
    create(:campus, :with_location, name: "Main")
    create(:group, :with_location, name: "Downtown Study", latitude: 36.17, longitude: -86.79)
    create(:household, :with_location, latitude: 36.15, longitude: -86.77)
    sign_in_as(create(:user, :staff))

    visit map_path

    expect(page).to have_css(".leaflet-container")
    expect(page).to have_css("path.leaflet-interactive", count: 3)
  end
end
