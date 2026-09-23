require "rails_helper"

RSpec.describe WorshipService do
  it_behaves_like "a tenant-scoped model"

  describe "#ensure_occurrences!" do
    let(:service) { create(:worship_service, day_of_week: 0, start_time: "09:00", duration_minutes: 75) }

    it "creates one occurrence per matching local date, once" do
      range = Date.new(2026, 10, 1)..Date.new(2026, 10, 31)
      2.times { service.ensure_occurrences!(range) }
      expect(service.occurrences.order(:local_date).pluck(:local_date)).to eq([ 4, 11, 18, 25 ].map { |d| Date.new(2026, 10, d) })
    end

    it "keeps 9am local across a daylight saving change" do
      service.ensure_occurrences!(Date.new(2026, 10, 25)..Date.new(2026, 11, 8)) # DST ends Nov 1 in the US
      times = service.occurrences.order(:starts_at).map { |o| o.starts_at.in_time_zone(church.zone) }
      expect(times.map(&:hour)).to all(eq(9))
      expect(times.map(&:utc_offset).uniq).to eq([ -5.hours.to_i, -6.hours.to_i ])
      expect(service.occurrences.first.ends_at - service.occurrences.first.starts_at).to eq(75.minutes)
    end
  end

  it "treats start_time as wall-clock time, whatever Time.zone is" do
    service = Time.use_zone("Central Time (US & Canada)") { create(:worship_service, start_time: "09:00") }

    [ "UTC", "Central Time (US & Canada)", "Tokyo" ].each do |zone|
      Time.use_zone(zone) do
        reloaded = WorshipService.find(service.id)
        expect(reloaded.start_time.strftime("%H:%M")).to eq("09:00")
        expect(reloaded.times_on(Date.new(2026, 10, 4)).first.in_time_zone(church.zone).hour).to eq(9)
      end
    end
  end
end
