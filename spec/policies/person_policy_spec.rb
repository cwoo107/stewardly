require "rails_helper"

RSpec.describe PersonPolicy do
  let(:person) { create(:person) }

  it "lets staff see and manage people" do
    policy = described_class.new(create(:user, :staff), person)
    expect([ policy.index?, policy.show?, policy.create?, policy.update?, policy.destroy?, policy.merge? ]).to all(be(true))
  end

  it "lets the care team see but not change people" do
    policy = described_class.new(create(:user, :care_team), person)
    expect([ policy.show?, policy.update?, policy.merge? ]).to eq([ true, false, false ])
  end

  it "keeps members out" do
    policy = described_class.new(create(:user, :member), person)
    expect([ policy.index?, policy.show?, policy.search? ]).to all(be(false))
  end

  it "lets ministry leaders search names to add members" do
    leader = create(:user, :member)
    create(:ministry_leadership, user: leader)
    expect(described_class.new(leader, Person).search?).to be(true)
  end

  it "scopes out merged people" do
    staff = create(:user, :staff)
    kept = create(:person)
    create(:person, merged_into: kept)
    expect(described_class::Scope.new(staff, Person).resolve).to contain_exactly(kept, staff.person)
  end
end
