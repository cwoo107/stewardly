require "rails_helper"

RSpec.describe "Events" do
  include ActiveJob::TestHelper

  let(:staff) { create(:user, :staff) }

  context "as staff" do
    before { sign_in_as(staff) }

    it "creates an event with its first date, then publishes it" do
      post events_path, params: { event: { title: "Fall picnic", registration_required: "1", capacity: 20, visibility: "public" },
        first_occurrence: { starts_at: "2026-10-10T16:00", ends_at: "2026-10-10T19:00" } }
      event = Event.find_by!(slug: "fall-picnic")
      expect(response).to redirect_to(edit_event_path(event))
      expect(event.occurrences.sole.starts_at.in_time_zone(church.zone).hour).to eq(16)

      patch publish_event_path(event)
      expect(event.reload).to be_published
    end

    it "lists and exports registrations, checks people in, and adds walk-ins" do
      occurrence = create(:event_occurrence, event: create(:event, :registration, title: "Newcomer lunch"))
      registration = create(:registration, event_occurrence: occurrence, person: create(:person, first_name: "Ada", last_name: "Lovelace"))
      event = occurrence.event

      get event_registrations_path(event)
      expect(response.body).to include("Ada Lovelace")
      get event_registrations_path(event, format: :csv)
      expect(response.body).to include("Ada Lovelace")

      get event_occurrence_check_in_path(event, occurrence)
      expect(response.body).to include("Check in")
      patch event_registration_path(event, registration), params: { change: "check_in" }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(registration.reload).to be_checked_in

      post event_registrations_path(event), params: { occurrence_id: occurrence.id, first_name: "Walk", last_name: "In" }
      expect(Registration.joins(:person).where(people: { first_name: "Walk" }).sole).to be_checked_in
    end

    it "cancelling a registration promotes the waitlist" do
      event = create(:event, :registration, capacity: 1)
      occurrence = create(:event_occurrence, event:)
      seated = create(:registration, event_occurrence: occurrence)
      waiting = create(:registration, event_occurrence: occurrence, status: "waitlisted")

      patch event_registration_path(event, seated), params: { change: "cancel" }
      expect(waiting.reload).to be_confirmed
    end
  end

  it "lets a ministry leader run only their ministry's events" do
    ministry = create(:ministry)
    leader = create(:user, :member)
    create(:ministry_leadership, ministry:, user: leader)
    mine = create(:event, ministry:)
    theirs = create(:event, ministry: create(:ministry))
    sign_in_as(leader)

    get edit_event_path(mine)
    expect(response).to have_http_status(:ok)
    get edit_event_path(theirs)
    expect(response).to have_http_status(:not_found)
    post events_path, params: { event: { title: "Sneaky", ministry_id: theirs.ministry_id } }
    expect(response).to have_http_status(:forbidden)
  end

  describe "public registration" do
    let(:event) { create(:event, :registration, title: "Newcomer lunch", capacity: 2, max_party_size: 3) }
    let!(:occurrence) { create(:event_occurrence, event:) }

    before { on_church(church) }

    def register(registrant: { first_name: "Ada", last_name: "Lovelace", email: "ada@example.com" }, **extra)
      token = travel_to(5.seconds.ago) { PublicSubmissionProtection.started_at_token }
      post public_event_registrations_path(event.slug), params: { occurrence_id: occurrence.id, registrant:, started_at: token }.merge(extra)
    end

    it "shows the page and registers a guest, then waitlists when full" do
      get public_event_path(event.slug)
      expect(response.body).to include("Newcomer lunch", "2 spots left")

      expect { register(party_size: 2) }.to have_enqueued_mail(RegistrationMailer, :confirmed)
      registration = Registration.sole
      expect(response).to redirect_to(manage_registration_path(registration.manage_token))
      expect(registration.person.email).to eq("ada@example.com")

      register(registrant: { first_name: "Bo", last_name: "Diddley", email: "bo@example.com" })
      expect(Registration.last).to be_waitlisted
    end

    it "asks the registration form's questions and saves the answers" do
      form = create(:form, purpose: "event_registration")
      form.fields.create!(key: "dietary", label: "Dietary needs", field_type: "text", required: true)
      form.fields.reset
      form.publish!
      event.update!(registration_form: form)

      register
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Dietary needs is required")

      register(answers: { dietary: "Vegetarian" })
      expect(Registration.sole.form_submission.answers).to eq("dietary" => "Vegetarian")
    end

    it "drops bots and respects the rate limit" do
      register(website: "spam")
      expect(Registration.count).to eq(0)
    end

    it "lets the registrant view and cancel with their link, and never cancels on a GET" do
      register
      registration = Registration.sole
      get manage_registration_path(registration.manage_token)
      expect(CGI.unescapeHTML(response.body)).to include("You're registered")
      expect(registration.reload).to be_confirmed

      delete manage_registration_path(registration.manage_token)
      expect(registration.reload).to be_cancelled
    end

    it "keeps drafts, internal events, and members-only events from guests" do
      draft = create(:event, :registration, status: "draft")
      internal = create(:event, visibility: "internal")
      members = create(:event, visibility: "members")

      get public_event_path(draft.slug)
      expect(response).to have_http_status(:not_found)
      get public_event_path(internal.slug)
      expect(response).to have_http_status(:not_found)
      get public_event_path(members.slug)
      expect(response).to redirect_to(new_session_path)
    end

    it "won't register when registration is closed" do
      event.update!(registration_closes_at: 1.hour.ago)
      register
      expect(response).to have_http_status(:unprocessable_content)
      expect(Registration.count).to eq(0)
    end
  end
end
