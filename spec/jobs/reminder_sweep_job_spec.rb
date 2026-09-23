require "rails_helper"

RSpec.describe ReminderSweepJob do
  it "runs each church's reminders only at 8am local time" do
    eastern = create(:church, time_zone: "Eastern Time (US & Canada)")
    pacific = create(:church, time_zone: "Pacific Time (US & Canada)")
    ran = []
    allow(Scheduling::Reminders).to receive(:new) { |church| ran << church; instance_double(Scheduling::Reminders, send_due!: 0) }
    ActsAsTenant.test_tenant = nil

    travel_to Time.utc(2026, 10, 5, 12, 5) do # 8:05am Eastern, 5:05am Pacific
      described_class.perform_now
    end

    expect(ran).to include(eastern)
    expect(ran).not_to include(pacific)
  end

  it "is scheduled hourly" do
    schedule = YAML.load_file(Rails.root.join("config/schedule.yml"))
    expect(schedule.dig("reminder_sweep", "class")).to eq("ReminderSweepJob")
  end
end
