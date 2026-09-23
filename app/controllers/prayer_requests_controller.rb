class PrayerRequestsController < ApplicationController
  before_action :set_prayer_request, only: %i[ show edit update destroy ]

  def index
    authorize PrayerRequest
    requests = policy_scope(PrayerRequest).includes(:person, assignees: :person).recent_first
    @status = params[:status].presence_in(PrayerRequest.statuses.keys) || "active"
    @pagy, @prayer_requests = pagy(requests.where(status: @status))
  end

  def show
    @assignable_users = User.alphabetical.includes(:person, :roles).select { |user| user.can?(:view_prayer_requests) } if policy(@prayer_request).assign?
  end

  def new
    person = policy_scope(Person).find_by(id: params[:person_id]) if params[:person_id]
    @prayer_request = authorize PrayerRequest.new(person:, visibility: default_visibility)
  end

  def create
    @prayer_request = authorize PrayerRequest.new(prayer_request_params.merge(created_by: Current.user, source: :staff))
    @prayer_request.visibility = default_visibility unless policy(@prayer_request).update?
    if @prayer_request.save
      redirect_to @prayer_request, notice: "Prayer request added."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @prayer_request.update(prayer_request_params)
      redirect_to @prayer_request, notice: "Saved."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @prayer_request.destroy!
    redirect_to prayer_requests_path, notice: "Prayer request deleted.", status: :see_other
  end

  private
    def set_prayer_request
      @prayer_request = authorize policy_scope(PrayerRequest).includes(:person, prayer_assignments: { user: :person }).find(params.expect(:id))
    end

    # Prayer team members can add requests, but only pastors decide who else sees them.
    def default_visibility
      Current.user.can?(:manage_prayer_requests) ? "pastoral_staff" : "prayer_team"
    end

    def prayer_request_params
      params.expect(prayer_request: %i[ person_id requester_name requester_email body visibility status answer_note ]).tap do |attributes|
        attributes[:person_id] = policy_scope(Person).find(attributes[:person_id]).id if attributes[:person_id].present?
      end
    end
end
