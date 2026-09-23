class CourseSessionsController < ApplicationController
  before_action :set_offering

  def create
    session = @offering.sessions.new(params.expect(course_session: %i[ starts_at ends_at topic ]))
    session.ends_at ||= session.starts_at && session.starts_at + 90.minutes
    if session.save
      redirect_to @offering, notice: "Session added.", status: :see_other
    else
      redirect_to @offering, alert: session.errors.full_messages.to_sentence, status: :see_other
    end
  end

  def destroy
    @offering.sessions.find(params.expect(:id)).destroy!
    redirect_to @offering, notice: "Session removed.", status: :see_other
  end

  private
    def set_offering
      @offering = authorize CourseOffering.find(params.expect(:course_offering_id)), :update?
    end
end
