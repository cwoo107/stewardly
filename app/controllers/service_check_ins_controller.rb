# Individual check-in for one service: search, check in, or add a guest.
class ServiceCheckInsController < ApplicationController
  def show
    authorize Attendance.new, :create?, policy_class: AttendanceRecordPolicy
    @occurrence = ServiceOccurrence.includes(:worship_service).find(params.expect(:service_occurrence_id))
    @attendances = @occurrence.attendances.includes(:person).joins(:person).merge(Person.alphabetical)
    checked_in = @attendances.map(&:person_id)
    @results = params[:q].to_s.strip.length >= 2 ? Person.unmerged.search(params[:q]).alphabetical.limit(10).reject { |p| checked_in.include?(p.id) } : []
  end
end
