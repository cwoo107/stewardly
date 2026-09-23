class GivingDashboardsController < ApplicationController
  def show
    authorize Donation, :index?
    @year = (params[:year].presence || Current.church.today.year).to_i
    @summary = Giving::Summary.new(year: @year)
  end
end
