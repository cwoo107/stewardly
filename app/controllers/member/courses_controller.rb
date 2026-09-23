class Member::CoursesController < Member::BaseController
  def index
    @enrollments = person.enrollments.current.includes(course_offering: [ :course, :sessions ])
    enrolled_ids = @enrollments.map(&:course_offering_id)
    @offerings = CourseOffering.open_for_enrollment(today).joins(:course).merge(Course.active).where.not(id: enrolled_ids)
      .includes(:course, :sessions, :leader).chronological
  end
end
