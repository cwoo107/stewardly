class Member::CalendarsController < Member::BaseController
  def show
    @month = (Date.parse("#{params[:month]}-01") rescue today).beginning_of_month
    @feed = Calendar::Feed.new(viewer: Current.user, range: [ @month, today ].max..@month.end_of_month, audience: :member)
  end
end
