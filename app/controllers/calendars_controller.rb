class CalendarsController < ApplicationController
  def show
    authorize :calendar
    @month = (Date.parse("#{params[:month]}-01") rescue Current.church.today).beginning_of_month
    @view = params[:view] == "agenda" ? "agenda" : "month"
    range = @view == "agenda" ? @month..@month.end_of_month : Calendar::Month.range_for(@month)
    @feed = Calendar::Feed.new(viewer: Current.user, range:, audience: :staff)
    @calendar = Calendar::Month.new(month: @month, feed_items_by_date: @feed.by_date)
  end
end
