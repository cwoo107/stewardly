require "rails_helper"

RSpec.describe Attendance::Growth do
  let(:today) { Date.new(2026, 9, 20) } # a Sunday
  let(:service) { create(:worship_service) }

  before do
    service.ensure_occurrences!(Date.new(2025, 1, 1)..today)
    service.occurrences.each do |occurrence|
      total = occurrence.local_date.year == 2026 ? 220 : 200
      create(:attendance_count, service_occurrence: occurrence, total:, first_time_guests: 2)
    end
  end

  subject(:growth) { described_class.new(today:) }

  it "totals weeks and rolls averages" do
    weekly = growth.weekly(weeks: 4)
    expect(weekly.values.last).to eq(220)
    expect(growth.rolling({ a: 100, b: 200, c: 300 }, 2)).to eq(a: 100, b: 150, c: 250)
  end

  it "compares this year to date with the same stretch last year" do
    expect(growth.year_to_date).to include(this_year: 220, last_year: 200, change: 10.0)
  end

  it "averages weeks per month for both years" do
    by_year = growth.monthly_by_year
    expect(by_year["2025"]["Mar"]).to eq(200)
    expect(by_year["2026"]["Mar"]).to eq(220)
    expect(by_year["2026"]).not_to have_key("Oct")
  end

  it "adds first-time check-ins to first-time guests counted at the door" do
    occurrence = service.occurrences.find_by(local_date: today)
    create(:attendance, service_occurrence: occurrence)
    expect(growth.first_time_guests["Sep 2026"]).to eq((3 * 2) + 1) # three September Sundays so far
  end
end
