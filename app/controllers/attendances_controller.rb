class AttendancesController < ApplicationController
  before_action :set_occurrence

  def create
    attendance = authorize @occurrence.attendances.new(person: person_to_check_in, checked_in_by: Current.user), policy_class: AttendanceRecordPolicy
    if attendance.person && attendance.save
      redirect_to service_occurrence_check_in_path(@occurrence), notice: "#{attendance.person.name} checked in#{" (first time!)" if attendance.first_time?}.", status: :see_other
    else
      redirect_to service_occurrence_check_in_path(@occurrence), alert: attendance.errors.full_messages.to_sentence.presence || "Enter a first and last name.", status: :see_other
    end
  end

  def destroy
    attendance = authorize @occurrence.attendances.find(params.expect(:id)), policy_class: AttendanceRecordPolicy
    attendance.destroy!
    redirect_to service_occurrence_check_in_path(@occurrence), notice: "Removed.", status: :see_other
  end

  private
    def set_occurrence
      @occurrence = ServiceOccurrence.find(params.expect(:service_occurrence_id))
    end

    # An existing person, or a new guest (matched by email under the fill-blanks rule).
    def person_to_check_in
      return Person.unmerged.find(params[:person_id]) if params[:person_id].present?

      Person::Intake.new(email: params[:email], first_name: params[:first_name], last_name: params[:last_name]).person
    end
end
