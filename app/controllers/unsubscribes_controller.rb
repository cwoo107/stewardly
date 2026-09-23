# The unsubscribe link in every campaign, and the List-Unsubscribe header's one-click
# POST (RFC 8058, which mail apps send without cookies or CSRF tokens). GET only shows a
# confirmation, so link scanners can't unsubscribe anyone.
class UnsubscribesController < ApplicationController
  allow_unauthenticated_access
  skip_forgery_protection only: :create
  skip_after_action :verify_authorized # the delivery token is the authorization
  before_action :set_delivery

  rate_limit to: 30, within: 1.minute, only: :create, with: -> { head :too_many_requests }

  layout "public"

  def show
  end

  def create
    @delivery.unsubscribe!(all_topics: params[:scope] == "all")
    if request.format.html? && params["List-Unsubscribe"].blank?
      redirect_to unsubscribe_path(@delivery.token, done: 1), status: :see_other
    else
      head :ok
    end
  end

  private
    def set_delivery
      @delivery = Delivery.includes(:email_topic, campaign: :email_topic).find_by!(token: params.expect(:token).to_s)
    end
end
