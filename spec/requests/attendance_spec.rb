require "rails_helper"

RSpec.describe "Attendance" do
  let(:service) { create(:worship_service, name: "Sunday 9am") }
  let(:sunday) { church.today.sunday? ? church.today : church.today.prev_occurring(:sunday) }

  context "as staff" do
    before { sign_in_as(create(:user, :staff)) }

    it "enters counts for every service on a date" do
      service
      get attendance_counts_path(date: sunday)
      occurrence = ServiceOccurrence.find_by!(local_date: sunday)
      expect(response.body).to include("Sunday 9am", "Adults", "Online")

      patch attendance_counts_path(date: sunday), params: { counts: { occurrence.id => { breakdown: { "Adults" => "120", "Kids" => "30", "Online" => "50" }, first_time_guests: "4" } } }
      expect(response).to redirect_to(attendance_counts_path(date: sunday))
      expect(occurrence.attendance_count).to have_attributes(total: 200, first_time_guests: 4)
    end

    it "shows errors without losing the other services' counts" do
      service
      eleven = create(:worship_service, name: "Sunday 11am", start_time: "11:00")
      get attendance_counts_path(date: sunday)
      nine, late = ServiceOccurrence.where(local_date: sunday).order(:starts_at)
      patch attendance_counts_path(date: sunday), params: { counts: { nine.id => { total: "180" }, late.id => { total: "-3" } } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(nine.reload.attendance_count.total).to eq(180)
      expect(eleven.occurrences.sole.attendance_count).to be_nil
    end

    it "shows the dashboard with forecasts, charts, and accuracy" do
      service.ensure_occurrences!((church.today - 70)..(church.today + 7))
      service.occurrences.where(local_date: ...church.today).each { |o| create(:attendance_count, service_occurrence: o, total: 200) }
      upcoming = service.occurrences.where(starts_at: Time.current..).first
      Attendance::Forecaster.new(service).refresh!(upcoming)

      get attendance_path
      expect(response.body).to include("Coming up", "Why this number", "Trailing 6-week average", "Weekly attendance")
      get attendance_accuracy_path
      expect(response).to have_http_status(:ok)
    end

    it "manages special Sundays" do
      post special_sundays_path, params: { special_sunday: { name: "Friend day", local_date: "2026-10-18", expected_change_percent: 20 } }
      expect(SpecialSunday.sole.key).to eq("friend-day")
      get special_sundays_path
      expect(response.body).to include("Friend day", "Thanksgiving weekend")
    end

    it "checks people in, including new guests" do
      occurrence = create(:service_occurrence, worship_service: service)
      person = create(:person, first_name: "Ada")
      get service_occurrence_check_in_path(occurrence, q: "Ada")
      expect(response.body).to include("Ada")

      post service_occurrence_attendances_path(occurrence), params: { person_id: person.id }
      expect(flash[:notice]).to include("first time")
      post service_occurrence_attendances_path(occurrence), params: { first_name: "New", last_name: "Guest" }
      expect(occurrence.attendances.count).to eq(2)
    end
  end

  it "lets a counter-only role enter counts but not see reports" do
    usher = create(:user, roles: [ create(:role, permissions: %w[ record_attendance ]) ])
    sign_in_as(usher)
    get attendance_counts_path
    expect(response).to have_http_status(:ok)
    get attendance_path
    expect(response).to have_http_status(:forbidden)
  end

  it "keeps members and the care team out" do
    sign_in_as(create(:user, :care_team))
    [ attendance_path, attendance_counts_path, attendance_accuracy_path, special_sundays_path ].each do |path|
      get path
      expect(response).to have_http_status(:forbidden), path
    end
  end
end
