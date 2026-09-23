# How good past (frozen) forecasts were, compared with the counts that came in.
class Attendance::Accuracy
  def initialize(scope = AttendanceForecast.all)
    @forecasts = scope.where.not(frozen_at: nil).joins(service_occurrence: :attendance_count)
      .includes(service_occurrence: [ :attendance_count, :worship_service ]).order("service_occurrences.local_date DESC")
  end

  LIMIT = 26

  def rows = @rows ||= @forecasts.limit(LIMIT).to_a

  def mean_error_percent
    errors = rows.filter_map(&:error_percent)
    errors.empty? ? nil : (errors.sum / errors.size).round(1)
  end

  def within_range_percent
    measured = rows
    measured.empty? ? nil : (measured.count(&:within_range?) * 100.0 / measured.size).round
  end
end
