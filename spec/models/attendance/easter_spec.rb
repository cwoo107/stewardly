require "rails_helper"

RSpec.describe Attendance::Easter do
  {
    1818 => "03-22", # the earliest possible
    1943 => "04-25", # the latest possible
    2000 => "04-23", 2008 => "03-23", 2011 => "04-24", 2019 => "04-21", 2020 => "04-12", 2021 => "04-04",
    2022 => "04-17", 2023 => "04-09", 2024 => "03-31", 2025 => "04-20", 2026 => "04-05", 2027 => "03-28",
    2028 => "04-16", 2029 => "04-01", 2030 => "04-21", 2035 => "03-25", 2038 => "04-25", 2049 => "04-18"
  }.each do |year, month_day|
    it "puts Easter #{year} on #{month_day}" do
      expect(described_class.on(year)).to eq(Date.parse("#{year}-#{month_day}"))
    end
  end

  it "is always a Sunday" do
    expect((1900..2100).map { |year| described_class.on(year) }).to all(satisfy(&:sunday?))
  end
end
