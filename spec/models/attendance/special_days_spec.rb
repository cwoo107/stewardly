require "rails_helper"

RSpec.describe Attendance::SpecialDays do
  subject(:days) { described_class.new(church) }

  def keys(date) = days.for(date).map(&:key)

  it "recognises the built-in holidays on real dates" do
    expect(keys(Date.new(2026, 4, 5))).to eq([ "easter" ])
    expect(keys(Date.new(2026, 3, 29))).to eq([ "palm_sunday" ])
    expect(keys(Date.new(2026, 5, 10))).to eq([ "mothers_day" ])
    expect(keys(Date.new(2026, 6, 21))).to eq([ "fathers_day" ])
    expect(keys(Date.new(2026, 5, 24))).to eq([ "memorial_day_weekend" ]) # Memorial Day is Mon May 25
    expect(keys(Date.new(2026, 7, 5))).to eq([ "independence_day_weekend" ])
    expect(keys(Date.new(2026, 9, 6))).to eq([ "labor_day_weekend" ]) # Labor Day is Mon Sep 7
    expect(keys(Date.new(2026, 11, 29))).to eq([ "thanksgiving_weekend" ]) # Thanksgiving is Thu Nov 26
    expect(keys(Date.new(2026, 12, 20))).to eq([ "christmas" ])
    expect(keys(Date.new(2026, 12, 27))).to eq([ "new_years" ])
  end

  it "leaves ordinary Sundays alone" do
    expect(keys(Date.new(2026, 10, 11))).to be_empty
    expect(days.special?(Date.new(2026, 2, 8))).to be(false)
  end

  it "adds the church's own special Sundays, with any expected change" do
    create(:special_sunday, local_date: Date.new(2026, 8, 23), name: "Back to school", expected_change_percent: 15)
    day = days.for(Date.new(2026, 8, 23)).sole
    expect(day).to have_attributes(key: "church:back-to-school", label: "Back to school", override_percent: 15)
    expect(day.override_multiplier).to eq(1.15)
  end
end
