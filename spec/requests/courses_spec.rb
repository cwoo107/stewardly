require "rails_helper"

RSpec.describe "Courses" do
  let(:offering) { create(:course_offering, capacity: 10) }
  let(:session) { create(:course_session, course_offering: offering) }
  let(:enrollment) { create(:enrollment, course_offering: offering) }

  context "as staff" do
    before { sign_in_as(create(:user, :staff)) }

    it "creates courses, offerings, and sessions" do
      post courses_path, params: { course: { name: "Membership 101" } }
      course = Course.find_by!(name: "Membership 101")
      post course_offerings_path, params: { course_offering: { course_id: course.id, starts_on: "2026-10-04", capacity: 12 } }
      new_offering = course.offerings.sole
      post course_offering_sessions_path(new_offering), params: { course_session: { starts_at: "2026-10-04T12:15", topic: "Our story" } }
      expect(new_offering.sessions.sole).to have_attributes(topic: "Our story", local_date: Date.new(2026, 10, 4))
    end

    it "enrolls people, takes attendance, and marks completion" do
      person = create(:person, first_name: "Ada")
      post course_offering_enrollments_path(offering), params: { enrollment: { person_id: person.id } }
      enrolled = offering.enrollments.sole

      patch course_offering_attendance_path(offering), params: { present: { session.id.to_s => [ enrolled.id.to_s ] } }
      expect(session.session_attendances.sole).to have_attributes(enrollment: enrolled, present: true)

      patch course_offering_attendance_path(offering), params: { present: {} }
      expect(session.session_attendances.sole.present).to be(false)

      patch course_offering_enrollment_path(offering, enrolled), params: { change: "complete" }
      expect(enrolled.reload).to be_completed
    end
  end

  it "lets the offering's leader take attendance but not edit the offering" do
    leader = create(:user, :member)
    offering.update!(leader: leader.person)
    enrollment
    sign_in_as(leader)

    get course_offering_path(offering)
    expect(response).to have_http_status(:ok)
    patch course_offering_attendance_path(offering), params: { present: { session.id.to_s => [ enrollment.id.to_s ] } }
    expect(session.session_attendances.count).to eq(1)
    get edit_course_offering_path(offering)
    expect(response).to have_http_status(:forbidden)
  end

  it "keeps members out of course admin" do
    sign_in_as(create(:user, :member))
    get course_offering_path(offering)
    expect(response).to have_http_status(:forbidden)
  end
end
