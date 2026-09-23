class CourseOfferingsController < ApplicationController
  before_action :set_offering, only: %i[ show edit update destroy ]

  def show
    @enrollments = @offering.enrollments.includes(:person, :session_attendances).joins(:person).merge(Person.alphabetical)
    @sessions = @offering.sessions.includes(:session_attendances)
  end

  def new
    course = policy_scope(Course).find(params.expect(:course_id))
    @offering = authorize course.offerings.new(starts_on: Current.church.today.next_occurring(:sunday))
  end

  def create
    course = policy_scope(Course).find(params.dig(:course_offering, :course_id))
    @offering = authorize course.offerings.new(offering_params)
    if @offering.save
      redirect_to @offering, notice: "Offering added. Add its sessions next."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @offering.update(offering_params)
      @offering.with_lock { @offering.promote_waitlist! }.each { |e| EnrollmentMailer.promoted(e).deliver_later }
      redirect_to @offering, notice: "Saved."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @offering.destroy!
    redirect_to @offering.course, notice: "Offering deleted.", status: :see_other
  end

  private
    def set_offering
      @offering = CourseOffering.includes(:course, :leader).find(params.expect(:id))
      authorize @offering, action_name == "show" ? :show? : :update?
    end

    def offering_params
      params.expect(course_offering: %i[ leader_id starts_on ends_on location_name capacity enrollment_open ])
    end
end
