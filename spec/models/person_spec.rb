require "rails_helper"

RSpec.describe Person do
  it_behaves_like "a tenant-scoped model"

  it "requires first and last names" do
    expect(build(:person, first_name: "", last_name: "")).not_to be_valid
  end

  it "may belong to a household" do
    household = create(:household)
    person = create(:person, household:)
    expect(household.people).to contain_exactly(person)
    expect(build(:person, household: nil)).to be_valid
  end

  it "cannot join another church's household" do
    elsewhere = ActsAsTenant.with_tenant(create(:church)) { create(:household) }
    expect(build(:person, household_id: elsewhere.id)).not_to be_valid
  end

  it "defaults to a guest adult" do
    expect(described_class.new).to have_attributes(membership_status: "guest", household_role: "adult")
  end

  it "rejects unknown membership statuses" do
    expect(build(:person, membership_status: "royalty")).not_to be_valid
  end

  it "normalizes blank emails to nil and downcases the rest" do
    expect(build(:person, email: " ").email).to be_nil
    expect(build(:person, email: " Jo@Example.COM ").email).to eq("jo@example.com")
  end

  it "prefers the nickname in #name" do
    expect(build(:person, first_name: "Robert", nickname: "Bob", last_name: "Lee").name).to eq("Bob Lee")
    expect(build(:person, first_name: "Robert", nickname: nil, last_name: "Lee").name).to eq("Robert Lee")
  end

  describe "custom fields" do
    before do
      create(:custom_field, :select, key: "size")
      create(:custom_field, key: "baptized_on", field_type: "date")
    end

    it "casts and stores values by key" do
      person = create(:person, custom_field_values: { "size" => "M", "baptized_on" => "March 3 2024", "unknown" => "x" })
      expect(person.custom_fields).to eq("size" => "M", "baptized_on" => "2024-03-03")
    end

    it "removes a value when blanked" do
      person = create(:person, custom_field_values: { "size" => "M" })
      person.update!(custom_field_values: { "size" => "" })
      expect(person.reload.custom_fields).to eq({})
    end

    it "reports invalid values as validation errors" do
      person = build(:person, custom_field_values: { "size" => "XXL" })
      expect(person).not_to be_valid
      expect(person.errors[:custom_fields].first).to include("must be one of")
    end
  end

  it "searches names, nicknames, email, and phone" do
    ada = create(:person, first_name: "Ada", last_name: "Lovelace", email: "ada@example.com", phone: "615-555-0100")
    create(:person, first_name: "Bob", last_name: "Smith")
    expect(Person.search("ada love")).to contain_exactly(ada)
    expect(Person.search("555-0100")).to contain_exactly(ada)
    expect(Person.search("%")).to be_empty
  end

  it "computes age in the church's time zone" do
    travel_to Time.utc(2026, 9, 21, 3, 0) do # Sep 20 in Chicago
      expect(build(:person, birthdate: Date.new(2000, 9, 21)).age).to eq(25)
      expect(build(:person, birthdate: Date.new(2000, 9, 20)).age).to eq(26)
    end
  end

  it "audits deletion" do
    person = create(:person)
    expect { person.destroy! }.to change { AuditEvent.where(action: "person.deleted").count }.by(1)
  end

  it "can't be deleted while it has a login" do
    user = create(:user)
    expect(user.person.destroy).to be(false)
  end
end
