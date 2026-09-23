# Hourly (config/schedule.yml): at 2am in each church's zone, make sure the next two
# weeks of services exist and are forecast, and freeze forecasts for services that have started.
class ForecastSweepJob < ApplicationJob
  LOCAL_HOUR = 2
  WEEKS_AHEAD = 2

  queue_as :low

  def perform
    ActsAsTenant.without_tenant { Church.all.to_a }.each do |church|
      next unless church.now.hour == LOCAL_HOUR

      ActsAsTenant.with_tenant(church) { sweep(church) }
    end
  end

  private
    def sweep(church)
      AttendanceForecast.joins(:service_occurrence).where(frozen_at: nil, service_occurrences: { starts_at: ..Time.current })
        .update_all(frozen_at: Time.current)

      WorshipService.active.each do |service|
        service.ensure_occurrences!(church.today..(church.today + (WEEKS_AHEAD * 7)))
        forecaster = Attendance::Forecaster.new(service)
        service.occurrences.where(starts_at: Time.current.., cancelled: false).order(:starts_at).limit(WEEKS_AHEAD).each { |o| forecaster.refresh!(o) }
      end
    end
end
