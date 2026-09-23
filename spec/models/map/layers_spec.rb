require "rails_helper"

RSpec.describe Map::Layers do
  let(:staff) { create(:user, :staff) }
  let(:care) { create(:user, :care_team) }

  before do
    create(:household, :with_location, name: "The Exact household", latitude: 36.16271, longitude: -86.78164)
    create(:household, :with_location, latitude: 36.16279, longitude: -86.78161) # same ~1 km cell
    create(:group, :with_location, name: "Downtown Study")
    create(:campus, :with_location, name: "Main")
  end

  it "shows exact households to users who may see precise locations" do
    layers = described_class.new(user: staff).to_h
    expect(layers[:precise]).to be(true)
    expect(layers[:households].first).to include(name: "The Exact household", lat: 36.16271)
  end

  it "clusters households on a grid, without names, for everyone else" do
    layers = described_class.new(user: care).to_h
    expect(layers[:precise]).to be(false)
    expect(layers[:households]).to eq([ { lat: 36.16, lng: -86.78, count: 2 } ])
    expect(layers.to_json).not_to include("Exact")
    expect(layers[:households].to_json).not_to include("36.1627")
  end

  it "includes groups and campuses" do
    layers = described_class.new(user: care).to_h
    expect(layers[:groups].map { |g| g[:name] }).to eq([ "Downtown Study" ])
    expect(layers[:campuses].map { |c| c[:name] }).to eq([ "Main" ])
  end

  it "filters households by segment" do
    person = create(:person, household: Household.first, membership_status: "member")
    segment = create(:segment, definition: { conditions: [ { type: "membership_status", statuses: [ "member" ] } ] })
    expect(described_class.new(user: staff, segment:).to_h[:households].map { |h| h[:id] }).to eq([ person.household_id ])
  end
end
