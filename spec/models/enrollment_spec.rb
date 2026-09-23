require "rails_helper"

RSpec.describe Enrollment do
  it_behaves_like "a tenant-scoped model"

  it "is one per person per offering" do
    enrollment = create(:enrollment)
    expect(build(:enrollment, course_offering: enrollment.course_offering, person: enrollment.person)).not_to be_valid
  end
end
