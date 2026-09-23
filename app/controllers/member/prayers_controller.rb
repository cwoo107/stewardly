class Member::PrayersController < Member::BaseController
  def index
    @requests = PrayerRequest.shared.active.includes(:person).recent_first.limit(30)
    @prayer_form = Form.published.prayer_request_form.first
  end
end
