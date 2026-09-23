# Accept or decline from the request email. The link opens a page with buttons
# (mail scanners follow links, so a GET must never answer for someone).
class AssignmentResponsesController < ApplicationController
  allow_unauthenticated_access
  skip_after_action :verify_authorized # the secret token is the authorization
  before_action :set_assignment

  layout "public"

  def show
  end

  def update
    return redirect_to(assignment_response_path(@assignment.response_token), alert: "This date has passed.", status: :see_other) unless @assignment.respondable?

    params.expect(:answer) == "accept" ? @assignment.accept! : @assignment.decline!
    AssignmentMailer.declined(@assignment).deliver_later if @assignment.declined?
    redirect_to assignment_response_path(@assignment.response_token), notice: "Thanks for letting us know.", status: :see_other
  end

  private
    def set_assignment
      @assignment = Assignment.includes(:person, :schedulable, position: :team).find_by!(response_token: params.expect(:token).to_s)
    end
end
