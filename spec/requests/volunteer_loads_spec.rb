require "rails_helper"

RSpec.describe "Volunteer load" do
  let(:ministry) { create(:ministry) }
  let(:team) { create(:team, ministry:, name: "Greeters") }
  let(:other_team) { create(:team, name: "Band") }

  before do
    create(:team_membership, team:, person: create(:person, first_name: "Gina"))
    create(:team_membership, team: other_team, person: create(:person, first_name: "Bojangles"))
  end

  it "shows staff everyone and lets manage_pathways set thresholds" do
    sign_in_as(create(:user, :staff))
    get volunteer_load_path
    expect(response.body).to include("Gina", "Bojangles", "Healthy")

    patch volunteer_load_path, params: { thresholds: { "at_risk_consecutive_weeks" => "5" } }
    expect(church.reload.load_thresholds["at_risk_consecutive_weeks"]).to eq(5.0)
  end

  it "shows a ministry leader only their teams" do
    leader = create(:user, :member)
    create(:ministry_leadership, ministry:, user: leader)
    sign_in_as(leader)
    get volunteer_load_path
    expect(response.body).to include("Gina")
    expect(response.body).not_to include("Bojangles")
    patch volunteer_load_path, params: { thresholds: { "at_risk_teams" => "2" } }
    expect(response).to have_http_status(:forbidden)
  end

  it "keeps members out" do
    sign_in_as(create(:user, :member))
    get volunteer_load_path
    expect(response).to have_http_status(:forbidden)
  end

  it "warns on the board when an assignment tips someone into at risk" do
    sign_in_as(create(:user, :staff))
    church.update!(volunteer_load_thresholds: { "at_risk_consecutive_weeks" => 1 })
    occurrence = create(:service_occurrence, local_date: church.today + 7)
    position = create(:position, team:)
    post assignments_path, params: { assignment: { schedulable_type: "ServiceOccurrence", schedulable_id: occurrence.id, position_id: position.id,
      person_id: team.people.first.id } }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    expect(response.body).to include("is now at risk of burnout")
  end
end
