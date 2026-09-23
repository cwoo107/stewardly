require "rails_helper"

RSpec.describe Person::DuplicateFinder do
  subject(:pairs) { described_class.new.pairs }

  it "pairs people who share an email" do
    a = create(:person, email: "sam@example.com")
    b = create(:person, first_name: "Samuel", email: "sam@example.com")
    expect(pairs.map { |p| [ p.person, p.duplicate, p.reason ] }).to eq([ [ a, b, "same_email" ] ])
  end

  it "pairs same-named people who share a phone (ignoring formatting), birthdate, or household" do
    a = create(:person, first_name: "Jo", last_name: "Park", email: nil, phone: "(615) 555-0100")
    b = create(:person, first_name: "jo", last_name: "PARK", email: nil, phone: "615.555.0100")
    expect(pairs.map { |p| [ p.person, p.duplicate ] }).to eq([ [ a, b ] ])
  end

  it "ignores same names with nothing else in common, merged people, and dismissed pairs" do
    create(:person, first_name: "Jo", last_name: "Park", email: nil)
    create(:person, first_name: "Jo", last_name: "Park", email: nil)
    a = create(:person, email: "x@example.com")
    b = create(:person, email: "x@example.com")
    create(:duplicate_dismissal, person: a, other_person: b)
    c = create(:person, email: "y@example.com")
    create(:person, email: "y@example.com", merged_into: c)

    expect(pairs).to be_empty
  end

  it "stays within the church" do
    create(:person, email: "sam@example.com")
    ActsAsTenant.with_tenant(create(:church)) { create(:person, email: "sam@example.com") }
    expect(pairs).to be_empty
  end
end
