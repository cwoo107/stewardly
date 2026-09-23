# Saves the attendance grid: one checkbox per enrollment per session.
class SessionAttendancesController < ApplicationController
  def update
    @offering = authorize CourseOffering.find(params.expect(:course_offering_id)), :take_attendance?
    marked = params.fetch(:present, {}).to_unsafe_h # { session_id => [enrollment ids] }

    SessionAttendance.transaction do
      @offering.sessions.each do |session|
        present_ids = Array(marked[session.id.to_s]).map(&:to_i)
        @offering.enrollments.each do |enrollment|
          attendance = session.session_attendances.find_or_initialize_by(enrollment:)
          present = present_ids.include?(enrollment.id)
          attendance.new_record? && !present ? next : attendance.update!(present:)
        end
      end
    end
    redirect_to @offering, notice: "Attendance saved.", status: :see_other
  end
end
