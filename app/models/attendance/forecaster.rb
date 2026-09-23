# Runs Attendance::Forecast for one worship service against its stored counts, and
# keeps AttendanceForecast rows up to date (refreshed until the service starts, then frozen).
class Attendance::Forecaster
  BACKTEST_WEEKS = 12
  STORED_ERRORS_NEEDED = 8

  def initialize(service)
    @service = service
    @special_days = Attendance::SpecialDays.new(service.church)
  end

  def forecast(date)
    Attendance::Forecast.new(date:, history:, special_days: special_days_lookup, errors: errors_before(date)).call
  end

  # Stores the forecast for an upcoming occurrence; leaves started ones alone.
  def refresh!(occurrence)
    record = occurrence.forecast || occurrence.build_forecast
    return record if record.frozen? || occurrence.starts_at <= Time.current

    result = forecast(occurrence.local_date)
    return occurrence.forecast&.destroy unless result.enough?

    record.update!(expected: result.expected, low: result.low, high: result.high, expected_online: result.expected_online,
      factors: result.factors.map(&:to_h), model_version: AttendanceForecast::MODEL_VERSION, generated_at: Time.current)
    record
  end

  def history
    @history ||= AttendanceCount.joins(:service_occurrence)
      .where(service_occurrences: { worship_service_id: @service.id, cancelled: false })
      .order("service_occurrences.local_date").pluck("service_occurrences.local_date", :total, :breakdown)
      .map do |date, total, breakdown|
        online = breakdown.keys.any? { |category| Church.online_category?(category) } ?
          breakdown.sum { |category, count| Church.online_category?(category) ? count.to_i : 0 } : nil
        Attendance::Forecast::Point.new(date:, total:, online:)
      end
  end

  private
    def special_days_lookup
      @lookup ||= Hash.new { |cache, date| cache[date] = @special_days.for(date) }.then { |cache| ->(date) { cache[date] } }
    end

    # Percentage errors of past forecasts: stored, frozen ones when there are enough,
    # otherwise a back-test of the model on the most recent weeks.
    def errors_before(date)
      stored = AttendanceForecast.joins(service_occurrence: :attendance_count)
        .where(service_occurrences: { worship_service_id: @service.id, local_date: ...date }, model_version: AttendanceForecast::MODEL_VERSION)
        .where.not(frozen_at: nil).order("service_occurrences.local_date DESC").limit(26)
        .filter_map(&:error_percent).map { |percent| percent / 100.0 }
      return stored if stored.size >= STORED_ERRORS_NEEDED

      history.select { |point| point.date < date }.last(BACKTEST_WEEKS).filter_map do |point|
        result = Attendance::Forecast.new(date: point.date, history:, special_days: special_days_lookup).call
        (result.expected - point.total).abs.to_f / point.total if result.enough? && point.total.positive?
      end
    end
end
