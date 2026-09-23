# Staff and offering leaders: enroll someone, mark complete, withdraw.
class EnrollmentsController < ApplicationController
  before_action :set_offering

  def create
    authorize @offering.enrollments.new
    result = Enrollment::Booking.new(offering: @offering, person: Person.unmerged.find(params.expect(enrollment: [ :person_id ])[:person_id])).book!
    redirect_to @offering, notice: "#{result.enrollment.person.name} is #{result.enrollment.status}.", status: :see_other
  end

  def update
    enrollment = authorize @offering.enrollments.find(params.expect(:id))
    case params.expect(:change)
    when "complete" then enrollment.complete!
    when "withdraw" then enrollment.withdraw!
    when "reinstate" then enrollment.update!(status: :enrolled, completed_at: nil)
    end
    redirect_to @offering, notice: "#{enrollment.person.name} is #{enrollment.status}.", status: :see_other
  end

  private
    def set_offering
      @offering = CourseOffering.find(params.expect(:course_offering_id))
    end
end
