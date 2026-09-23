require "rails_helper"

RSpec.describe Scheduling::Reminders do
  include ActiveJob::TestHelper

  it "reminds volunteers N days ahead and event registrants the day before, once" do
    church.update!(reminder_days_before: 3)
    today = church.today
    soon = create(:service_occurrence, local_date: today + 3)
    later = create(:service_occurrence, local_date: today + 4)
    create(:assignment, schedulable: soon, status: "accepted")
    create(:assignment, schedulable: later)
    create(:assignment, schedulable: soon, status: "declined")
    tomorrow = church.zone.local((today + 1).year, (today + 1).month, (today + 1).day, 18)
    occurrence = create(:event_occurrence, starts_at: tomorrow, ends_at: tomorrow + 1.hour)
    create(:registration, event_occurrence: occurrence)
    create(:registration, event_occurrence: occurrence, status: "waitlisted")

    expect { described_class.new(church).send_due! }
      .to have_enqueued_mail(AssignmentMailer, :reminder).exactly(1).times
      .and have_enqueued_mail(RegistrationMailer, :reminder).exactly(1).times
    expect { described_class.new(church).send_due! }.not_to have_enqueued_mail
  end
end
