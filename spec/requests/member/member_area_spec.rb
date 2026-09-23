require "rails_helper"

RSpec.describe "Member area" do
  include ActiveJob::TestHelper

  let(:user) { create(:user, :member) }
  let(:person) { user.person }

  before { sign_in_as(user) }

  it "shows home, schedule, calendar, events, classes, groups, profile, and prayer" do
    create(:announcement, title: "Picnic Sunday")
    [ member_root_path, member_assignments_path, member_calendar_path, member_events_path, member_courses_path,
      member_groups_path, member_profile_path, member_prayers_path ].each do |path|
      get path
      expect(response).to have_http_status(:ok), "#{path} was #{response.status}"
    end
    get member_root_path
    expect(response.body).to include("Picnic Sunday")
  end

  it "answers serving requests and manages blockouts" do
    assignment = create(:assignment, person:, schedulable: create(:service_occurrence, local_date: church.today + 7))
    patch member_assignment_path(assignment), params: { answer: "accept" }
    expect(assignment.reload).to be_accepted

    post member_blockouts_path, params: { blockout: { starts_on: church.today + 14, reason: "Away" } }
    expect(person.blockouts.sole.reason).to eq("Away")
  end

  it "can't answer someone else's request" do
    other = create(:assignment, schedulable: create(:service_occurrence, local_date: church.today + 7))
    patch member_assignment_path(other), params: { answer: "decline" }
    expect(response).to have_http_status(:not_found)
    expect(other.reload).to be_pending
  end

  it "registers for and cancels events" do
    event = create(:event, :registration, visibility: "members")
    occurrence = create(:event_occurrence, event:)
    post member_event_registrations_path(event), params: { occurrence_id: occurrence.id }
    registration = person.registrations.sole
    expect(registration).to be_confirmed

    delete member_registration_path(registration)
    expect(registration.reload).to be_cancelled
  end

  it "doesn't show internal or draft events" do
    internal = create(:event, visibility: "internal")
    get member_event_path(internal)
    expect(response).to have_http_status(:not_found)
  end

  it "enrolls in and withdraws from classes" do
    offering = create(:course_offering)
    post member_enrollments_path, params: { course_offering_id: offering.id }
    enrollment = person.enrollments.sole
    expect(enrollment).to be_enrolled

    delete member_enrollment_path(enrollment)
    expect(enrollment.reload).to be_withdrawn
  end

  it "asks to join a group" do
    group = create(:group)
    expect { post member_group_join_requests_path(group), params: { group_join_request: { message: "Hi!" } } }
      .to have_enqueued_mail(GroupJoinRequestMailer, :received)
    expect(person.group_join_requests.sole).to have_attributes(group:, message: "Hi!")
  end

  it "edits their own profile, household address, and household members" do
    patch member_profile_path, params: { person: { first_name: "Tommy", last_name: person.last_name, phone: "615-555-0199" },
      household: { address_line1: "1 Elm St", city: "Nashville", postal_code: "37203" } }
    expect(person.reload).to have_attributes(first_name: "Tommy", phone: "615-555-0199")
    expect(person.household.address_line1).to eq("1 Elm St")

    post member_household_members_path, params: { person: { first_name: "Kid", last_name: person.last_name, household_role: "child" } }
    expect(person.household.people.map(&:first_name)).to include("Kid")
  end

  it "can't edit someone outside their household" do
    person.update!(household: create(:household))
    stranger = create(:person)
    get edit_member_household_member_path(stranger)
    expect(response).to have_http_status(:not_found)
  end

  it "shows only shared prayer requests" do
    create(:prayer_request, body: "Shared one", visibility: "shared")
    create(:prayer_request, body: "Team only", visibility: "prayer_team")
    get member_prayers_path
    expect(response.body).to include("Shared one")
    expect(response.body).not_to include("Team only")
  end

  it "keeps members-only forms to signed-in people" do
    form = create(:form, :published, access: "members")
    get public_form_path(form.slug)
    expect(response).to have_http_status(:ok)
    delete session_path
    get public_form_path(form.slug)
    expect(response).to redirect_to(new_session_path)
  end
end
