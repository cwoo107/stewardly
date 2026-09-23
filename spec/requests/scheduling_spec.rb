require "rails_helper"

RSpec.describe "Volunteer scheduling" do
  include ActiveJob::TestHelper

  let(:ministry) { create(:ministry) }
  let(:team) { create(:team, ministry:) }
  let(:position) { create(:position, team:, name: "Greeter") }
  let(:service) { create(:worship_service, name: "Sunday 9am") }
  let(:volunteer) { create(:person, first_name: "Vera", email: "vera@example.com") }

  before do
    create(:position_need, needable: service, position:, quantity: 1)
    create(:team_membership, team:, person: volunteer)
  end

  context "as staff" do
    before { sign_in_as(create(:user, :staff)) }

    it "manages services and their needs" do
      post worship_services_path, params: { worship_service: { name: "Sunday 11am", day_of_week: 0, start_time: "11:00", duration_minutes: 75 } }
      eleven = WorshipService.find_by!(name: "Sunday 11am")
      post position_needs_path, params: { position_need: { needable_type: "WorshipService", needable_id: eleven.id, position_id: position.id, quantity: 2 } }
      expect(eleven.position_needs.sole.quantity).to eq(2)
      get edit_worship_service_path(eleven)
      expect(response.body).to include("Greeter")
    end

    it "shows the board, auto-fills, and sends requests" do
      get team_schedule_path(team)
      expect(response.body).to include("Sunday 9am", "Greeter", "1 of 1 open")

      post auto_fill_team_schedule_path(team)
      expect(Assignment.where(person: volunteer).count).to be >= 1

      expect { post send_requests_team_schedule_path(team) }.to have_enqueued_mail(AssignmentMailer, :request_to_serve).at_least(:once)
      expect(Assignment.awaiting_request).to be_empty
    end

    it "creates, moves, and removes assignments with Turbo Streams" do
      service.ensure_occurrences!(church.today..church.today + 14)
      first, second = service.occurrences.order(:local_date).first(2)
      headers = { "Accept" => "text/vnd.turbo-stream.html" }

      post assignments_path, params: { assignment: { schedulable_type: "ServiceOccurrence", schedulable_id: first.id, position_id: position.id, person_id: volunteer.id } }, headers: headers
      assignment = Assignment.sole
      expect(response.body).to include("turbo-stream", "Vera")

      patch assignment_path(assignment), params: { assignment: { schedulable_type: "ServiceOccurrence", schedulable_id: second.id, position_id: position.id } }, headers: headers
      expect(assignment.reload.schedulable).to eq(second)

      delete assignment_path(assignment), headers: headers
      expect(Assignment.count).to eq(0)
    end

    it "loads suggestions for a slot" do
      service.ensure_occurrences!(church.today..church.today + 7)
      get suggestions_assignments_path(schedulable_type: "ServiceOccurrence", schedulable_id: service.occurrences.first.id, position_id: position.id)
      expect(response.body).to include("Vera", "hasn&#39;t served in 8 weeks")
    end

    it "rejects unknown schedulable types" do
      post assignments_path, params: { assignment: { schedulable_type: "User", schedulable_id: 1, position_id: position.id, person_id: volunteer.id } }
      expect(response).to have_http_status(:not_found)
    end

    it "sets qualifications and monthly maximums" do
      post team_position_qualifications_path(team), params: { position_qualification: { position_id: position.id, person_id: volunteer.id } }
      expect(position.qualified_people).to contain_exactly(volunteer)

      membership = team.team_memberships.find_by!(person: volunteer)
      patch team_team_membership_path(team, membership), params: { team_membership: { max_per_month: 2 } }
      expect(membership.reload.max_per_month).to eq(2)
    end
  end

  context "as a leader of another ministry" do
    before do
      leader = create(:user, :member)
      create(:ministry_leadership, user: leader)
      sign_in_as(leader)
    end

    it "can't see or change this team's schedule" do
      get team_schedule_path(team)
      expect(response).to have_http_status(:forbidden)
      service.ensure_occurrences!(church.today..church.today + 7)
      post assignments_path, params: { assignment: { schedulable_type: "ServiceOccurrence", schedulable_id: service.occurrences.first.id, position_id: position.id, person_id: volunteer.id } }
      expect(response).to have_http_status(:forbidden)
    end
  end

  it "lets this team's ministry leader schedule it" do
    leader = create(:user, :member)
    create(:ministry_leadership, ministry:, user: leader)
    sign_in_as(leader)
    get team_schedule_path(team)
    expect(response).to have_http_status(:ok)
  end

  describe "answering from the email link" do
    let(:assignment) do
      service.ensure_occurrences!(church.today..church.today + 7)
      create(:assignment, schedulable: service.occurrences.first, position:, person: volunteer)
    end

    before { on_church(church) }

    it "shows buttons without answering on a GET" do
      get assignment_response_path(assignment.response_token)
      expect(response.body).to include("Can you serve?")
      expect(assignment.reload).to be_pending
    end

    it "accepts, and a decline tells the leaders" do
      patch assignment_response_path(assignment.response_token), params: { answer: "accept" }
      expect(assignment.reload).to be_accepted

      expect { patch assignment_response_path(assignment.response_token), params: { answer: "decline" } }
        .to have_enqueued_mail(AssignmentMailer, :declined)
      expect(assignment.reload).to be_declined
    end

    it "rejects unknown tokens" do
      get assignment_response_path("nope")
      expect(response).to have_http_status(:not_found)
    end
  end
end
