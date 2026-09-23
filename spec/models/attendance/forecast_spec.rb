require "rails_helper"

RSpec.describe Attendance::Forecast do
  Point = Attendance::Forecast::Point

  let(:target) { Date.new(2026, 10, 11) } # an ordinary Sunday
  let(:none) { ->(_date) { [] } }

  # Weekly points ending the Sunday before the target.
  def weekly(weeks, from: target, &value)
    (1..weeks).map { |back| from - (back * 7) }.reverse.each_with_index.map do |date, index|
      Point.new(date:, total: value.call(index, date).round, online: nil)
    end
  end

  def forecast(history, special_days: none, errors: [], date: target)
    described_class.new(date:, history:, special_days:, errors:).call
  end

  it "needs enough history" do
    result = forecast(weekly(4) { 200 })
    expect(result).not_to be_enough
    expect(result.reason).to include("at least 6 weeks")
  end

  it "forecasts a flat history as its average" do
    result = forecast(weekly(10) { 200 })
    expect(result.expected).to eq(200)
    expect(result.factors.map(&:label)).to eq([ "Trailing 6-week average" ])
  end

  it "projects a steady trend forward" do
    result = forecast(weekly(20) { |week| 200 + (week * 2) }) # +2 a week; last value 238
    expect(result.expected).to be_within(1).of(240)
    trend = result.factors.find { |f| f.label.start_with?("Trend") }
    expect(trend.label).to include("+2.0 a week")
  end

  it "blends in the same week last year, grown by year-over-year change" do
    history = weekly(110) { |_week, date| date.year == 2025 && date.month == 10 && date.day.between?(9, 15) ? 260 : (date < target - 365 ? 200 : 220) }
    result = forecast(history)
    last_year = result.factors.find { |f| f.label.start_with?("Same week last year") }
    expect(last_year.detail).to match(/\+10\.\d% vs the year before/) # the 260 week sits inside the recent 12 months
    # baseline 220; last year 260 × ~1.10 ≈ 287; halfway ≈ 253
    expect(result.expected).to be_within(1).of(253)
  end

  it "has factors that add up to the forecast" do
    history = weekly(110) { |week| 180 + week + (week % 3) }
    result = forecast(history)
    expect(result.factors.sum(&:effect).round).to eq(result.expected)
  end

  describe "special days" do
    let(:easter) { Date.new(2026, 4, 5) }
    let(:special_days) { Attendance::SpecialDays.new(church).then { |days| ->(date) { days.for(date) } } }

    it "learns the effect from the church's past Easters" do
      history = weekly(120, from: easter) { |_w, date| date == Attendance::Easter.on(date.year) ? 350 : 200 }
      result = forecast(history, special_days:, date: easter)
      factor = result.factors.find { |f| f.label.start_with?("Easter") }
      expect(factor.label).to include("×1.75")
      expect(factor.detail).to include("Learned from your last 2 Easters")
    end

    it "uses the typical effect without history of its own, and uses last year's Easter, not 52 weeks ago" do
      history = weekly(20, from: easter) { 200 }
      result = forecast(history, special_days:, date: easter)
      factor = result.factors.find { |f| f.label.start_with?("Easter") }
      expect(factor.detail).to include("Typical effect")
      expect(result.expected).to eq(320) # 200 × 1.6
    end

    it "prefers the church's expected change" do
      create(:special_sunday, local_date: target, name: "Friend day", expected_change_percent: 25)
      result = forecast(weekly(10) { 200 }, special_days:)
      expect(result.expected).to eq(250)
      expect(result.factors.last.detail).to include("Your expected change of +25%")
    end

    it "leaves special days out of the baseline" do
      history = weekly(10, from: easter + 7) { |_w, date| date == easter ? 500 : 200 }
      result = forecast(history, special_days:, date: easter + 7)
      expect(result.factors.first.effect).to eq(200)
    end
  end

  it "sets the range from past errors, at least ±5%" do
    history = weekly(10) { 200 }
    expect(forecast(history, errors: [ 0.01, 0.02, 0.03 ])).to have_attributes(low: 190, high: 210)
    expect(forecast(history, errors: [ 0.1, 0.2, 0.2, 0.2, 0.3 ])).to have_attributes(low: 160, high: 240)
    expect(forecast(history)).to have_attributes(low: 180, high: 220) # no errors yet: ±10%
  end

  it "splits in person and online by recent shares" do
    history = weekly(10) { 200 }.map { |p| p.with(online: 50) }
    expect(forecast(history).expected_online).to eq(50)
    expect(forecast(weekly(10) { 200 }).expected_online).to be_nil
  end

  it "never looks at the target date or later" do
    history = weekly(10) { 200 } + [ Point.new(date: target, total: 9999, online: nil), Point.new(date: target + 7, total: 9999, online: nil) ]
    expect(forecast(history).expected).to eq(200)
  end
end
