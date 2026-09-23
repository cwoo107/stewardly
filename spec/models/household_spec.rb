require "rails_helper"

RSpec.describe Household do
  it_behaves_like "a tenant-scoped model"

  it "requires a name" do
    expect(build(:household, name: "")).not_to be_valid
  end

  describe "location (PostGIS)" do
    it "is a geography point in SRID 4326 with a GiST index" do
      column = described_class.columns_hash.fetch("location")
      expect(column.sql_type).to eq("geography(Point,4326)")

      index = described_class.connection.indexes(:households).find { |i| i.columns == [ "location" ] }
      expect(index.using).to eq(:gist)
    end

    it "round-trips latitude and longitude through the database" do
      household = create(:household, :with_location, latitude: 36.1627, longitude: -86.7816)

      household.reload
      expect(household.latitude).to be_within(1e-6).of(36.1627)
      expect(household.longitude).to be_within(1e-6).of(-86.7816)
    end

    it "measures real-world distance in meters in the database" do
      downtown = create(:household, :with_location, latitude: 36.1627, longitude: -86.7816)
      create(:household, :with_location, latitude: 36.1447, longitude: -86.8027) # ~2.8 km away

      point = "SRID=4326;POINT(-86.8027 36.1447)"
      nearby = Household.where("ST_DWithin(location, ST_GeogFromText(?), 1000)", point)
      within_5km = Household.where("ST_DWithin(location, ST_GeogFromText(?), 5000)", point)

      expect(nearby).not_to include(downtown)
      expect(within_5km).to include(downtown)
    end
  end

  describe "#display_location_for" do
    let(:household) { create(:household, :with_location, latitude: 36.16271, longitude: -86.78164) }

    it "gives exact coordinates with view_precise_locations" do
      expect(household.display_location_for(create(:user, :staff))).to eq([ household.latitude, household.longitude ])
    end

    it "snaps to a ~1 km grid otherwise" do
      expect(household.display_location_for(create(:user, :care_team))).to eq([ 36.16, -86.78 ])
    end
  end

  it "lists the nearest active groups first" do
    household = create(:household, :with_location, latitude: 36.1627, longitude: -86.7816)
    far = create(:group, :with_location, latitude: 36.25, longitude: -86.70)
    near = create(:group, :with_location, latitude: 36.165, longitude: -86.78)
    create(:group, :with_location, active: false)

    expect(household.nearest_groups.to_a).to eq([ near, far ])
  end
end
