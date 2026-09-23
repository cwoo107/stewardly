class PrayerAssignmentsController < ApplicationController
  before_action :set_prayer_request

  def create
    assignment = authorize @prayer_request.prayer_assignments.new(user: User.find(params.expect(prayer_assignment: [ :user_id ])[:user_id]))
    if assignment.save
      redirect_to @prayer_request, notice: "Assigned to #{assignment.user.name}.", status: :see_other
    else
      redirect_to @prayer_request, alert: assignment.errors.full_messages.to_sentence, status: :see_other
    end
  end

  def destroy
    assignment = authorize @prayer_request.prayer_assignments.find(params.expect(:id))
    assignment.destroy!
    redirect_to @prayer_request, notice: "Unassigned #{assignment.user.name}.", status: :see_other
  end

  private
    def set_prayer_request
      @prayer_request = PrayerRequest.find(params.expect(:prayer_request_id))
    end
end
