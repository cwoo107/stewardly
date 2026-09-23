require "rails_helper"

RSpec.describe Assignment do
  it_behaves_like "a tenant-scoped model"

  it "copies the occurrence's local date and gets a response token" do
    assignment = create(:assignment)
    expect(assignment.local_date).to eq(assignment.schedulable.local_date)
    expect(assignment.response_token).to be_present
  end

  it "schedules a person once per position per occurrence" do
    assignment = create(:assignment)
    expect(build(:assignment, schedulable: assignment.schedulable, position: assignment.position, person: assignment.person)).not_to be_valid
  end

  it "can't be scheduled on another church's occurrence" do
    foreign = ActsAsTenant.with_tenant(create(:church)) { create(:service_occurrence) }
    expect(build(:assignment, schedulable: foreign)).not_to be_valid
  end

  it "records answers" do
    assignment = create(:assignment)
    assignment.accept!
    expect(assignment).to have_attributes(status: "accepted", responded_at: be_present)
  end

  it "stops taking answers once the occurrence is over" do
    past = create(:service_occurrence, local_date: Date.current - 7)
    expect(build(:assignment, schedulable: past)).not_to be_respondable
  end
end
