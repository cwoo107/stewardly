require "rails_helper"

RSpec.describe AttendanceCount do
  include ActiveJob::TestHelper

  it_behaves_like "a tenant-scoped model"

  it "adds up a breakdown into the total and splits online" do
    count = create(:attendance_count, total: nil, breakdown: { "Adults" => "150", "Kids" => "40", "Online" => "60", "Ignored" => "" })
    expect(count).to have_attributes(total: 250, online: 60, in_person: 190)
    expect(count.breakdown).to eq("Adults" => 150, "Kids" => 40, "Online" => 60)
  end

  it "accepts a plain total" do
    count = create(:attendance_count, total: 180)
    expect([ count.online, count.online_known? ]).to eq([ 0, false ])
  end

  it "rejects bad numbers" do
    expect(build(:attendance_count, breakdown: { "Adults" => "lots" })).not_to be_valid
    expect(build(:attendance_count, total: -1)).not_to be_valid
  end

  it "refreshes the service's forecasts" do
    expect { create(:attendance_count) }.to have_enqueued_job(AttendanceForecastRefreshJob)
  end
end
