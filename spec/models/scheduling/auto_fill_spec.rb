require "rails_helper"

RSpec.describe Scheduling::AutoFill do
  let(:team) { create(:team) }
  let(:position) { create(:position, team:) }
  let(:range) { Date.new(2026, 10, 4)..Date.new(2026, 10, 17) } # two Sundays

  before do
    %w[ Ann Ben Cal ].each { |name| create(:team_membership, team:, person: create(:person, first_name: name)) }
  end

  it "fills each open slot with pending assignments, spreading the load, and sends nothing" do
    service = create(:worship_service)
    create(:position_need, needable: service, position:, quantity: 2)

    count = nil
    expect { count = described_class.new(team:, range:, assigned_by: nil).fill! }.not_to have_enqueued_mail
    expect(count).to eq(4)
    expect(Assignment.pending.count).to eq(4)
    expect(Assignment.group(:person_id).count.values.sort).to eq([ 1, 1, 2 ])
  end

  it "doesn't double-book a day across services" do
    early = create(:worship_service, name: "9am")
    late = create(:worship_service, name: "11am", start_time: "11:00")
    [ early, late ].each { |service| create(:position_need, needable: service, position:, quantity: 2) }

    described_class.new(team:, range: range.first..range.first, assigned_by: nil).fill!

    expect(Assignment.group(:person_id, :local_date).count.values).to all(eq(1))
    expect(Assignment.count).to eq(3) # only three people, four slots
  end

  it "is idempotent" do
    create(:position_need, needable: create(:worship_service), position:, quantity: 1)
    described_class.new(team:, range:, assigned_by: nil).fill!
    expect { described_class.new(team:, range:, assigned_by: nil).fill! }.not_to change(Assignment, :count)
  end

  it "includes event dates that need the team" do
    event = create(:event)
    create(:event_occurrence, event:, starts_at: church.zone.local(2026, 10, 10, 10), ends_at: church.zone.local(2026, 10, 10, 12))
    create(:position_need, needable: event, position:, quantity: 1)

    described_class.new(team:, range:, assigned_by: nil).fill!
    expect(Assignment.sole.schedulable).to be_a(EventOccurrence)
  end
end
