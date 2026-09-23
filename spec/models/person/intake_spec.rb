require "rails_helper"

RSpec.describe Person::Intake do
  it "is a signed-in user's own person, who may update their details" do
    user = create(:user)
    intake = described_class.new(user:, email: "someone@else.com")
    expect(intake.person).to eq(user.person)
    intake.update(user.person, first_name: "Renamed")
    expect(user.person.first_name).to eq("Renamed")
  end

  it "matches by email and only fills blanks for anonymous people" do
    existing = create(:person, first_name: "Ada", email: "ada@example.com", phone: nil)
    intake = described_class.new(email: " ADA@example.com ", first_name: "Hacker", last_name: "X")
    expect(intake.person).to eq(existing)

    intake.update(existing, first_name: "Hacker", phone: "615-555-0100")
    expect(existing).to have_attributes(first_name: "Ada", phone: "615-555-0100")
  end

  it "creates a guest for a new name, or nothing without one" do
    expect(described_class.new(email: "new@example.com", first_name: "New", last_name: "Person").person).to have_attributes(membership_status: "guest", email: "new@example.com")
    expect(described_class.new(email: "who@example.com").person).to be_nil
  end
end
