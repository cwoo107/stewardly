class Member::EnrollmentsController < Member::BaseController
  def create
    offering = CourseOffering.open_for_enrollment(today).find(params.expect(:course_offering_id))
    result = Enrollment::Booking.new(offering:, person:).book!
    redirect_to member_courses_path, notice: result.enrollment.waitlisted? ? "It's full, so you're on the waitlist." : "You're enrolled!", status: :see_other
  end

  def destroy
    enrollment = person.enrollments.find(params.expect(:id))
    authorize enrollment, :withdraw_own?
    enrollment.withdraw!
    redirect_to member_courses_path, notice: "You've withdrawn.", status: :see_other
  end
end
