require "rails_helper"

RSpec.describe Map::CoverageGap do
  it "finds households with no active group within the radius" do
    create(:group, :with_location, latitude: 36.1627, longitude: -86.7816)
    create(:group, :with_location, latitude: 36.40, longitude: -86.40, active: false)
    near = create(:household, :with_location, latitude: 36.17, longitude: -86.78)
    far = create(:household, :with_location, latitude: 36.40, longitude: -86.40)
    create(:household) # not located

    gap = described_class.new(miles: 3)
    expect(gap.households).to contain_exactly(far)
    expect(gap.households).not_to include(near)

    person = create(:person, household: far)
    expect(gap.people).to contain_exactly(person)
  end
end
