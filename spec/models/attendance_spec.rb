require "rails_helper"

RSpec.describe Attendance do
  it_behaves_like "a tenant-scoped model"

  it "marks a person's first ever check-in" do
    person = create(:person)
    first = create(:attendance, person:)
    second = create(:attendance, person:, service_occurrence: create(:service_occurrence, local_date: first.service_occurrence.local_date + 7))
    expect([ first.first_time, second.first_time ]).to eq([ true, false ])
  end

  it "checks someone in once per service" do
    attendance = create(:attendance)
    expect(build(:attendance, service_occurrence: attendance.service_occurrence, person: attendance.person)).not_to be_valid
  end
end
