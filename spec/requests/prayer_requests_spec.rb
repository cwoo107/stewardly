require "rails_helper"

RSpec.describe "Prayer requests" do
  let(:pastor) { create(:user, :church_admin) }
  let(:prayer_team) { create(:user, :care_team) }
  let(:person) { create(:person, first_name: "Ruth", last_name: "Ames") }
  let!(:team_request) { create(:prayer_request, person:, body: "Job interview Friday", visibility: "prayer_team") }
  let!(:pastoral_request) { create(:prayer_request, person:, body: "Marriage counseling", visibility: "pastoral_staff") }

  it "shows pastors every request" do
    sign_in_as(pastor)
    get prayer_requests_path
    expect(response.body).to include("Job interview Friday", "Marriage counseling")
  end

  it "shows the prayer team only what's shared with them" do
    sign_in_as(prayer_team)
    get prayer_requests_path
    expect(response.body).to include("Job interview Friday")
    expect(response.body).not_to include("Marriage counseling")
    get prayer_request_path(pastoral_request)
    expect(response).to have_http_status(:not_found)
  end

  it "lets prayer team members add requests, visible to the prayer team" do
    sign_in_as(prayer_team)
    post prayer_requests_path, params: { prayer_request: { requester_name: "A visitor", body: "Safe travels", visibility: "pastoral_staff" } }
    expect(PrayerRequest.last).to have_attributes(visibility: "prayer_team", source: "staff", created_by: prayer_team)
  end

  it "lets pastors assign, answer, and follow up" do
    sign_in_as(pastor)

    post prayer_request_prayer_assignments_path(pastoral_request), params: { prayer_assignment: { user_id: prayer_team.id } }
    expect(pastoral_request.assignees).to contain_exactly(prayer_team)

    patch prayer_request_path(pastoral_request), params: { prayer_request: { status: "answered", answer_note: "Reconciled" } }
    expect(pastoral_request.reload).to have_attributes(status: "answered", answer_note: "Reconciled")

    post prayer_request_follow_ups_path(pastoral_request), params: { follow_up: { body: "Called to celebrate" } }
    follow_up = person.touchpoints.sole
    expect(follow_up).to have_attributes(kind: "prayer_follow_up", sensitive: true, subject: pastoral_request, body: "Called to celebrate")
  end

  it "lets an assigned prayer team member see a pastoral request but not edit it" do
    create(:prayer_assignment, prayer_request: pastoral_request, user: prayer_team)
    sign_in_as(prayer_team)
    get prayer_request_path(pastoral_request)
    expect(response.body).to include("Marriage counseling")
    patch prayer_request_path(pastoral_request), params: { prayer_request: { visibility: "shared" } }
    expect(response).to have_http_status(:forbidden)
  end

  it "keeps staff without prayer permissions out" do
    sign_in_as(create(:user, :staff))
    get prayer_requests_path
    expect(response).to have_http_status(:forbidden)
    get person_path(person)
    expect(response.body).not_to include("Job interview Friday")
  end
end
