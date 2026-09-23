class SpecialSundaysController < ApplicationController
  before_action :set_special_sunday, only: %i[ edit update destroy ]

  def index
    authorize SpecialSunday
    @special_sundays = policy_scope(SpecialSunday).where(local_date: Current.church.today.prev_year..).chronological
    special_days = Attendance::SpecialDays.new(Current.church)
    today = Current.church.today
    @built_in = (today..today.next_year).select(&:sunday?).filter_map do |date|
      days = special_days.for(date).reject { |day| day.key.start_with?("church:") }
      [ date, days ] if days.any?
    end
  end

  def new
    @special_sunday = authorize SpecialSunday.new(local_date: Current.church.today.next_occurring(:sunday))
  end

  def create
    @special_sunday = authorize SpecialSunday.new(special_sunday_params)
    if @special_sunday.save
      refresh_forecasts
      redirect_to special_sundays_path, notice: "#{@special_sunday.name} added."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @special_sunday.update(special_sunday_params)
      refresh_forecasts
      redirect_to special_sundays_path, notice: "Saved."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @special_sunday.destroy!
    refresh_forecasts
    redirect_to special_sundays_path, notice: "Removed.", status: :see_other
  end

  private
    def set_special_sunday
      @special_sunday = authorize policy_scope(SpecialSunday).find(params.expect(:id))
    end

    def special_sunday_params
      params.expect(special_sunday: %i[ name local_date expected_change_percent ])
    end

    def refresh_forecasts
      WorshipService.active.each { |service| AttendanceForecastRefreshJob.perform_later(service) }
    end
end
