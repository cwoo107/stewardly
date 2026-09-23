require "rails_helper"

RSpec.describe PositionQualification do
  it_behaves_like "a tenant-scoped model"

  it "requires the person to be on the position's team" do
    qualification = PositionQualification.new(position: create(:position), person: create(:person))
    expect(qualification).not_to be_valid
    expect(qualification.errors[:person].first).to include("must be on the")
  end
end
