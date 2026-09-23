class CoursesController < ApplicationController
  before_action :set_course, only: %i[ show edit update destroy ]

  def index
    authorize Course
    @courses = policy_scope(Course).alphabetical.includes(offerings: :enrollments)
  end

  def show
    @offerings = @course.offerings.includes(:leader, :enrollments, :sessions)
  end

  def new
    @course = authorize Course.new(ministry_id: params[:ministry_id]), :new?
  end

  def create
    @course = authorize Course.new(course_params)
    if @course.save
      redirect_to @course, notice: "Course added."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    @course.assign_attributes(course_params)
    authorize @course
    if @course.save
      redirect_to @course, notice: "Saved."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @course.destroy!
    redirect_to courses_path, notice: "Course deleted.", status: :see_other
  end

  private
    def set_course
      @course = authorize policy_scope(Course).find(params.expect(:id))
    end

    def course_params
      params.expect(course: %i[ name description ministry_id active ])
    end
end
