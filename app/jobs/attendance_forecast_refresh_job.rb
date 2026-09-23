# New counts change the next forecasts for that service.
class AttendanceForecastRefreshJob < ApplicationJob
  queue_as :low

  discard_on ActiveJob::DeserializationError

  def perform(worship_service)
    forecaster = Attendance::Forecaster.new(worship_service)
    worship_service.occurrences.where(starts_at: Time.current..).order(:starts_at).limit(2).each { |occurrence| forecaster.refresh!(occurrence) }
  end
end
