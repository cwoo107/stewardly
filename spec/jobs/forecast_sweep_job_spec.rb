require "rails_helper"

RSpec.describe ForecastSweepJob do
  it "forecasts upcoming services and freezes started ones at 2am local time" do
    service = create(:worship_service)
    travel_to church.zone.local(2026, 10, 7, 2, 15) do # Wednesday 2:15am Chicago
      service.ensure_occurrences!(Date.new(2026, 8, 1)..Date.new(2026, 10, 4))
      service.occurrences.each { |o| create(:attendance_count, service_occurrence: o, total: 200) }
      stale = create(:attendance_forecast, service_occurrence: service.occurrences.order(:local_date).last)
      ActsAsTenant.test_tenant = nil

      described_class.perform_now

      ActsAsTenant.with_tenant(church) do
        expect(stale.reload).to be_frozen
        upcoming = service.occurrences.where(local_date: Date.new(2026, 10, 11)..).order(:local_date)
        expect(upcoming.size).to eq(2)
        expect(upcoming.map { |o| o.forecast&.expected }).to eq([ 200, 200 ])
      end
    end
  end

  it "does nothing at other hours" do
    create(:worship_service)
    travel_to church.zone.local(2026, 10, 7, 9) do
      ActsAsTenant.test_tenant = nil
      described_class.perform_now
    end
    expect(ActsAsTenant.with_tenant(church) { ServiceOccurrence.count }).to eq(0)
  end
end
