# One form for every service on a date: totals or breakdowns, and first-time guests.
class AttendanceCountsController < ApplicationController
  before_action { authorize :attendance, :record? }
  before_action :set_date_and_occurrences

  def edit
  end

  def update
    params.fetch(:counts, {}).each do |occurrence_id, attributes|
      occurrence = @occurrences.find { |o| o.id == occurrence_id.to_i } or next
      count = occurrence.attendance_count || occurrence.build_attendance_count
      attributes = attributes.permit(:total, :first_time_guests, :note, breakdown: {})
      next if count.new_record? && attributes.values_at(:total, :first_time_guests).all?(&:blank?) && attributes[:breakdown].to_h.values.all?(&:blank?)

      count.assign_attributes(attributes.merge(recorded_by: Current.user))
      count.save || (@errors ||= {})[occurrence.id] = count.errors.full_messages.to_sentence
    end

    if @errors.present?
      flash.now[:alert] = "Some counts weren't saved."
      render :edit, status: :unprocessable_content
    else
      redirect_to attendance_counts_path(date: @date), notice: "Counts saved.", status: :see_other
    end
  end

  private
    def set_date_and_occurrences
      @date = (Date.iso8601(params[:date].to_s) rescue nil) || most_recent_service_date
      WorshipService.active.each { |service| service.ensure_occurrences!(@date..@date) }
      @occurrences = ServiceOccurrence.where(local_date: @date).includes(:worship_service, :attendance_count).order(:starts_at).to_a
    end

    def most_recent_service_date
      days = WorshipService.active.pluck(:day_of_week).uniq
      today = Current.church.today
      (0..6).map { |back| today - back }.find { |date| days.include?(date.wday) } || today
    end
end
