require "rails_helper"

RSpec.describe CourseOffering do
  include ActiveJob::TestHelper

  it_behaves_like "a tenant-scoped model"

  let(:offering) { create(:course_offering, capacity: 1) }

  it "enrolls, then waitlists, and promotes when someone withdraws" do
    first = Enrollment::Booking.new(offering:, person: create(:person)).book!.enrollment
    second = Enrollment::Booking.new(offering:, person: create(:person)).book!.enrollment
    expect([ first.status, second.status ]).to eq(%w[ enrolled waitlisted ])

    expect { first.withdraw! }.to have_enqueued_mail(EnrollmentMailer, :promoted)
    expect(second.reload).to be_enrolled
  end

  it "lets someone re-enroll after withdrawing" do
    person = create(:person)
    enrollment = Enrollment::Booking.new(offering:, person:).book!.enrollment
    enrollment.withdraw!
    again = Enrollment::Booking.new(offering:, person:).book!
    expect(again).to have_attributes(created: true)
    expect(again.enrollment.reload).to be_enrolled
  end

  it "counts completed people as seated" do
    Enrollment::Booking.new(offering:, person: create(:person)).book!.enrollment.complete!
    expect(offering).to be_full
  end
end
