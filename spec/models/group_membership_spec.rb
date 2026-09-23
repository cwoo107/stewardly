require "rails_helper"

RSpec.describe GroupMembership do
  it_behaves_like "a tenant-scoped model"

  it "stops people joining a full group" do
    group = create(:group, capacity: 1)
    create(:group_membership, group:)
    membership = build(:group_membership, group: group.reload)
    expect(membership).not_to be_valid
    expect(membership.errors[:base].first).to include("is full")
  end

  it "records the join date in the church's time zone" do
    travel_to Time.utc(2026, 9, 21, 3, 0) do # Sep 20 in Chicago
      expect(create(:group_membership).joined_on).to eq(Date.new(2026, 9, 20))
    end
  end
end
