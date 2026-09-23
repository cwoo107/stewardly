class AttendanceForecastsController < ApplicationController
  def index
    authorize :attendance, :accuracy?
    @services = WorshipService.ordered
    @service = @services.find { |service| service.id == params[:worship_service_id].to_i } || @services.first
    scope = policy_scope(AttendanceForecast).joins(:service_occurrence)
    scope = scope.where(service_occurrences: { worship_service_id: @service.id }) if @service
    @accuracy = Attendance::Accuracy.new(scope)
    @rows = @accuracy.rows
  end
end
