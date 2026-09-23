require "rails_helper"

RSpec.describe Scheduling::Board do
  it "lays out needs, assignments, and conflicts" do
    team = create(:team)
    position = create(:position, team:)
    service = create(:worship_service)
    create(:position_need, needable: service, position:, quantity: 2)
    person = create(:person)
    board = described_class.new(team:, range: Date.new(2026, 10, 4)..Date.new(2026, 10, 4))

    occurrence = board.occurrences.sole
    assignment = create(:assignment, schedulable: occurrence, position:, person:)
    create(:blockout, person:, starts_on: Date.new(2026, 10, 4))
    board = described_class.new(team:, range: Date.new(2026, 10, 4)..Date.new(2026, 10, 4))

    cell = board.cell(occurrence, position)
    expect([ cell.needed, cell.open_slots, cell.assignments ]).to eq([ 2, 1, [ assignment ] ])
    expect(board.conflicts_for(assignment)).to eq([ "Blocked out that day" ])
    expect(board.open_slot_count).to eq(1)
  end
end
