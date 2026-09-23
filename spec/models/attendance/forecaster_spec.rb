require "rails_helper"

RSpec.describe Attendance::Forecaster do
  let(:service) { create(:worship_service) }
  let(:today) { church.today }

  before do
    service.ensure_occurrences!((today - 70)..(today + 14))
    service.occurrences.where(local_date: ...today).each do |occurrence|
      create(:attendance_count, service_occurrence: occurrence, breakdown: { "Adults" => 150, "Online" => 50 })
    end
  end

  let(:upcoming) { service.occurrences.where(starts_at: Time.current..).order(:starts_at).first }

  it "stores a forecast for an upcoming occurrence, with the online split" do
    forecast = described_class.new(service).refresh!(upcoming)
    expect(forecast).to have_attributes(expected: 200, expected_online: 50, model_version: AttendanceForecast::MODEL_VERSION)
    expect(forecast.factors.first["label"]).to eq("Trailing 6-week average")
  end

  it "leaves frozen or started forecasts alone" do
    forecast = described_class.new(service).refresh!(upcoming)
    forecast.update!(frozen_at: Time.current, expected: 1)
    described_class.new(service).refresh!(upcoming.reload)
    expect(forecast.reload.expected).to eq(1)
  end

  it "back-tests to size the range until there are enough stored forecasts" do
    result = described_class.new(service).forecast(upcoming.local_date)
    expect(result.band).to eq(Attendance::Forecast::MIN_BAND) # perfectly steady history
  end

  it "only reads this service's counts" do
    other = create(:worship_service, name: "Other", start_time: "11:00")
    other.ensure_occurrences!((today - 14)..today)
    other.occurrences.each { |o| create(:attendance_count, service_occurrence: o, total: 9999) }
    expect(described_class.new(service).history.map(&:total).uniq).to eq([ 200 ])
  end
end
