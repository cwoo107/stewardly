require "rails_helper"

RSpec.describe EventOccurrence do
  it_behaves_like "a tenant-scoped model"

  it "stores the local date in the church's zone" do
    occurrence = create(:event_occurrence, starts_at: Time.utc(2026, 9, 21, 3, 0), ends_at: Time.utc(2026, 9, 21, 4, 0)) # 10pm Sep 20 Chicago
    expect(occurrence.local_date).to eq(Date.new(2026, 9, 20))
  end

  it "uses its own capacity or the event's" do
    event = create(:event, capacity: 10)
    expect(create(:event_occurrence, event:).capacity_limit).to eq(10)
    expect(create(:event_occurrence, event:, capacity: 3).capacity_limit).to eq(3)
  end
end
