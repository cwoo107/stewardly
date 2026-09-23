require "rails_helper"

RSpec.describe Group do
  it_behaves_like "a tenant-scoped model"

  it "has a geography location with a GiST index" do
    expect(described_class.columns_hash.fetch("location").sql_type).to eq("geography(Point,4326)")
    expect(described_class.connection.indexes(:groups).find { |i| i.columns == [ "location" ] }.using).to eq(:gist)
  end

  describe ".nearest_to" do
    it "orders by distance using PostGIS and reports miles" do
      origin = Group.point(latitude: 36.1627, longitude: -86.7816)
      far = create(:group, :with_location, latitude: 36.30, longitude: -86.70)
      near = create(:group, :with_location, latitude: 36.17, longitude: -86.78)
      create(:group) # no location

      results = Group.nearest_to(origin).to_a
      expect(results).to eq([ near, far ])
      expect(results.first.distance_miles).to be_within(0.2).of(0.5)
    end
  end

  it "summarizes when it meets" do
    group = build(:group, meeting_frequency: "biweekly", meeting_day: 2, meeting_time: "19:00")
    expect(group.meeting_summary).to eq("Biweekly · Tuesday · 7:00 PM")
  end
end
