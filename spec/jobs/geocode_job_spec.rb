require "rails_helper"

RSpec.describe GeocodeJob do
  it "geocodes the record in the church that enqueued it" do
    stub_geocoding("1 Elm St, Nashville, 37203, US", latitude: 36.1, longitude: -86.7)
    household = create(:household, address_line1: "1 Elm St", city: "Nashville", region: nil, postal_code: "37203")
    ActsAsTenant.test_tenant = nil

    ActsAsTenant.with_tenant(church) { described_class.perform_now(household) }

    expect(ActsAsTenant.with_tenant(church) { household.reload.latitude }).to be_within(1e-6).of(36.1)
  end

  it "queues on the low queue and retries provider errors" do
    expect(described_class.new.queue_name).to eq("low")
    household = create(:household)
    allow(household).to receive(:geocode!).and_raise(Geocoder::ServiceUnavailable)
    expect { described_class.perform_now(household) }.to have_enqueued_job(described_class)
  end
end
