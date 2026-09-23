class AttendanceDashboardsController < ApplicationController
  def show
    authorize :attendance, :show?
    today = Current.church.today
    @upcoming = WorshipService.active.ordered.includes(:campus).map do |service|
      occurrence = service.occurrences.where(starts_at: Time.current..).order(:starts_at).includes(:forecast).first
      [ service, occurrence, occurrence&.forecast ]
    end
    @recent = AttendanceCount.joins(:service_occurrence).includes(service_occurrence: [ :worship_service, :forecast ])
      .order("service_occurrences.starts_at DESC").limit(8)
    @growth = Attendance::Growth.new(today:)
    @weekly = @growth.weekly
    @ytd = @growth.year_to_date
    @missing = ServiceOccurrence.joins(:worship_service).merge(WorshipService.active)
      .where(local_date: (today - 28)..today, cancelled: false).where(starts_at: ...Time.current).where.missing(:attendance_count)
      .order(:starts_at).includes(:worship_service)
  end
end
