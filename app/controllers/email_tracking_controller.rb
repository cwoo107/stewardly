# Open pixel and click redirects. Clicks only redirect to URLs we signed when the
# campaign was compiled (Email::Tracking), so this can't be used as an open redirect.
class EmailTrackingController < ApplicationController
  PIXEL = Base64.decode64("R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7").freeze

  allow_unauthenticated_access
  skip_after_action :verify_authorized # public tracking; no data is revealed
  skip_around_action :use_church_time_zone

  def open
    Delivery.find_by(token: params[:token].to_s)&.record_open!
    response.headers["Cache-Control"] = "no-store, private"
    send_data PIXEL, type: "image/gif", disposition: "inline"
  end

  def click
    url = Email::Tracking.target_for(params[:signed])
    return head(:not_found) unless url.is_a?(String) && url.match?(%r{\Ahttps?://}i)

    Delivery.find_by(token: params[:token].to_s)&.record_click!
    redirect_to url, allow_other_host: true, status: :found
  end
end
