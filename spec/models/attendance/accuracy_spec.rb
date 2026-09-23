require "rails_helper"

RSpec.describe Attendance::Accuracy do
  it "measures frozen forecasts against counts" do
    service = create(:worship_service)
    service.ensure_occurrences!((church.today - 21)..church.today)
    occurrences = service.occurrences.order(:local_date).first(2)
    [ [ 200, 210 ], [ 200, 300 ] ].zip(occurrences).each do |(expected, actual), occurrence|
      create(:attendance_forecast, service_occurrence: occurrence, expected:, low: 180, high: 220, frozen_at: Time.current)
      create(:attendance_count, service_occurrence: occurrence, total: actual)
    end
    create(:attendance_forecast, service_occurrence: service.occurrences.order(:local_date).last) # not frozen: ignored

    accuracy = described_class.new
    expect(accuracy.rows.size).to eq(2)
    expect(accuracy.within_range_percent).to eq(50)
    expect(accuracy.mean_error_percent).to eq(((10 / 210.0 + 100 / 300.0) * 100 / 2).round(1))
  end
end
