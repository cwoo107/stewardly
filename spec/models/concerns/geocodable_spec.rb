require "rails_helper"

RSpec.describe Geocodable do
  include ActiveJob::TestHelper

  let(:address) { { address_line1: "100 Main St", city: "Nashville", region: "TN", postal_code: "37203" } }

  it "queues geocoding after the address changes" do
    household = create(:household, address_line1: nil)
    expect { household.update!(address) }.to have_enqueued_job(GeocodeJob).with(household)
    expect { household.update!(name: "Renamed") }.not_to have_enqueued_job(GeocodeJob)
  end

  it "doesn't geocode when the same save sets a location" do
    expect { create(:household, :with_location, **address) }.not_to have_enqueued_job(GeocodeJob)
  end

  it "stores the point from the geocoder" do
    stub_geocoding("100 Main St, Nashville, TN 37203, US", latitude: 36.16, longitude: -86.78)
    group = create(:group, **address)

    group.geocode!

    expect(group.reload).to have_attributes(latitude: be_within(1e-6).of(36.16), longitude: be_within(1e-6).of(-86.78), geocode_error: nil)
  end

  it "records when an address can't be found" do
    campus = create(:campus, **address)
    campus.geocode!
    expect(campus.reload).to have_attributes(location: nil, geocode_error: "Address not found")
  end

  it "clears the location when the address is removed" do
    household = create(:household, :with_location, address_line1: nil)
    household.geocode!
    expect(household.reload.location).to be_nil
  end
end
