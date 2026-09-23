# Forecasts one service's attendance on a date from its history. A pure function:
# it only ever looks at points before the date, so it can be back-tested.
#
#   1. Baseline: average of the last 6 normal (non-special) weeks.
#   2. Trend: least-squares line through the last 12 months of normal weeks,
#      projecting the baseline forward to the date.
#   3. Special day: a multiplier learned from this church's own past days of the
#      same kind (actual / baseline at the time), else a church override, else a default.
#   4. Last year: the same week last year (or the same holiday) × year-over-year growth
#      (the last 12 months of normal weeks vs the 12 before; both span every season,
#      so a summer dip doesn't read as decline), blended 50/50.
#   5. Range: the 80th percentile of past percentage errors, at least ±5%.
#
# Every step is recorded as a Factor whose effects sum to the expected number.
class Attendance::Forecast
  Point = Data.define(:date, :total, :online)
  Factor = Data.define(:label, :effect, :detail) do
    def to_h = { "label" => label, "effect" => effect.round(1), "detail" => detail }
  end
  Result = Data.define(:expected, :low, :high, :expected_online, :factors, :band) do
    def enough? = true
  end
  NotEnough = Data.define(:reason) do
    def enough? = false
  end

  MIN_POINTS = 6
  BASELINE_WEEKS = 6
  TREND_WINDOW = 365
  MIN_TREND_POINTS = 8
  LAST_YEAR_WEIGHT = 0.5
  LEARNED_DAYS = 3
  ERROR_PERCENTILE = 0.8
  MIN_BAND = 0.05
  DEFAULT_BAND = 0.10

  def initialize(date:, history:, special_days:, errors: [])
    @date = date
    @history = history.select { |point| point.date < date }.sort_by(&:date)
    @special_days = special_days
    @errors = errors
  end

  def call
    return NotEnough.new("Needs at least #{MIN_POINTS} weeks of counts, #{MIN_POINTS - 2} of them ordinary.") if @history.size < MIN_POINTS || normal.size < MIN_POINTS - 2

    factors = []
    baseline_points = normal.last(BASELINE_WEEKS)
    baseline = mean(baseline_points.map(&:total))
    factors << Factor.new("Trailing #{baseline_points.size}-week average", baseline,
      "Ordinary weeks #{I18n.l(baseline_points.first.date, format: :short)} – #{I18n.l(baseline_points.last.date, format: :short)}")

    estimate = baseline
    if slope && (shift = slope * (@date - midpoint(baseline_points))).abs >= 0.5
      factors << Factor.new("Trend (#{format("%+.1f", slope * 7)} a week)", shift,
        "Line through the last 12 months, projected #{((@date - midpoint(baseline_points)) / 7.0).round} weeks ahead")
      estimate += shift
    end

    special.each do |day|
      multiplier, source = multiplier_for(day)
      factors << Factor.new("#{day.label} (×#{format("%.2f", multiplier)})", estimate * (multiplier - 1), source)
      estimate *= multiplier
    end

    if (anchor = last_year)
      value, date, label = anchor
      adjusted = value * (1 + growth_rate)
      factors << Factor.new("#{label} (#{I18n.l(date, format: :short)}: #{value})", LAST_YEAR_WEIGHT * (adjusted - estimate),
        "#{value} × #{format("%.2f", 1 + growth_rate)} (#{format("%+.1f", growth_rate * 100)}% vs the year before) = #{adjusted.round}, blended half and half")
      estimate += LAST_YEAR_WEIGHT * (adjusted - estimate)
    end

    expected = [ estimate.round, 0 ].max
    band = range_band
    Result.new(expected:, low: (expected * (1 - band)).round, high: (expected * (1 + band)).round,
      expected_online: online_share && (expected * online_share).round, factors:, band:)
  end

  private
    def special = @special ||= @special_days.call(@date)
    def special_on?(date) = @special_days.call(date).any?
    def normal = @normal ||= @history.reject { |point| special_on?(point.date) }
    def mean(values) = values.sum.to_f / values.size
    def midpoint(points) = points.first.date + ((points.last.date - points.first.date) / 2)

    # People per day, from a least-squares line through the last year of ordinary weeks.
    def slope
      return @slope if defined?(@slope)

      points = normal.select { |point| point.date >= @date - TREND_WINDOW }
      return @slope = nil if points.size < MIN_TREND_POINTS

      xs = points.map { |point| (point.date - points.first.date).to_f }
      ys = points.map(&:total)
      x_mean, y_mean = mean(xs), mean(ys)
      denominator = xs.sum { |x| (x - x_mean)**2 }
      raw = denominator.zero? ? 0 : xs.zip(ys).sum { |x, y| (x - x_mean) * (y - y_mean) } / denominator
      @trend_mean = y_mean
      # Keep the implied annual growth between -50% and +100%.
      @slope = raw.clamp(-0.5 * y_mean / 365, 1.0 * y_mean / 365)
    end

    # Year-over-year change in ordinary weeks: the last 12 months vs the 12 before.
    # Falls back to the trend line's implied yearly growth, then to none.
    def growth_rate
      @growth_rate ||= begin
        recent = normal.select { |point| point.date >= @date - 365 }
        earlier = normal.select { |point| point.date.between?(@date - 730, @date - 366) }
        if recent.size >= MIN_TREND_POINTS && earlier.size >= MIN_TREND_POINTS
          (mean(recent.map(&:total)) / mean(earlier.map(&:total)) - 1).clamp(-0.5, 1.0)
        elsif slope
          slope * 365 / @trend_mean
        else
          0.0
        end
      end
    end

    # Church override, else this church's history for the kind of day, else the default.
    def multiplier_for(day)
      return [ day.override_multiplier, "Your expected change of #{format("%+d", day.override_percent)}%" ] if day.override_multiplier

      ratios = @history.select { |point| @special_days.call(point.date).any? { |d| d.key == day.key } }.last(LEARNED_DAYS).filter_map do |point|
        before = normal.select { |p| p.date < point.date }.last(BASELINE_WEEKS)
        point.total / mean(before.map(&:total)) if before.size >= MIN_POINTS - 2
      end
      if ratios.any?
        [ mean(ratios), "Learned from your last #{ratios.size == 1 ? "one" : ratios.size} #{day.label.pluralize(ratios.size)}" ]
      else
        [ day.default_multiplier, "Typical effect (no history of your own yet)" ]
      end
    end

    # The same holiday last year for special days; otherwise the ordinary week closest to 52 weeks ago.
    def last_year
      if special.any?
        keys = special.map(&:key)
        point = @history.reverse.find do |p|
          p.date.between?(@date - 400, @date - 330) && @special_days.call(p.date).any? { |day| keys.include?(day.key) }
        end
        point && [ point.total, point.date, "Same day last year" ]
      else
        target = @date - 364
        point = normal.select { |p| (p.date - target).abs <= 3 }.min_by { |p| (p.date - target).abs }
        point && [ point.total, point.date, "Same week last year" ]
      end
    end

    def range_band
      return DEFAULT_BAND if @errors.empty?

      sorted = @errors.sort
      [ sorted[((sorted.size - 1) * ERROR_PERCENTILE).round], MIN_BAND ].max
    end

    def online_share
      recent = @history.reject { |point| point.online.nil? }.last(BASELINE_WEEKS)
      return if recent.empty?

      total = recent.sum(&:total)
      total.zero? ? nil : recent.sum(&:online).to_f / total
    end
end
