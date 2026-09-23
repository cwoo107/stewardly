require "rails_helper"

RSpec.describe AttendanceForecast do
  it_behaves_like "a tenant-scoped model"

  it "compares with the actual count" do
    forecast = create(:attendance_forecast, expected: 200, low: 180, high: 220)
    create(:attendance_count, service_occurrence: forecast.service_occurrence, total: 250)
    expect(forecast.reload).to have_attributes(actual: 250, error_percent: 20.0, within_range?: false)
  end
end
