require "rails_helper"

RSpec.describe Person::Merge do
  let(:survivor) { create(:person, first_name: "Sam", last_name: "Lee", email: "sam@example.com", phone: nil) }
  let(:duplicate) { create(:person, first_name: "Samuel", last_name: "Lee", email: nil, phone: "555-0100", birthdate: Date.new(1990, 1, 2)) }

  def merge! = described_class.new(survivor:, duplicate:).merge!

  it "fills blank details, moves related records, hides the duplicate, and audits" do
    shared_tag, extra_tag = create_list(:tag, 2)
    survivor.tags << shared_tag
    duplicate.tags << [ shared_tag, extra_tag ]
    group = create(:group)
    create(:group_membership, group:, person: duplicate)
    touchpoint = create(:touchpoint, person: duplicate)
    request = create(:prayer_request, person: duplicate)
    login = create(:user, person: duplicate, email_address: "samuel@example.com")

    merge!

    survivor.reload
    expect(survivor).to have_attributes(email: "sam@example.com", phone: "555-0100", birthdate: Date.new(1990, 1, 2))
    expect(survivor.tags).to contain_exactly(shared_tag, extra_tag)
    expect(survivor.groups).to contain_exactly(group)
    expect([ touchpoint.reload.person, request.reload.person, login.reload.person ]).to all(eq(survivor))
    expect(duplicate.reload).to be_merged
    expect(Person.unmerged).not_to include(duplicate)
    expect(AuditEvent.last).to have_attributes(action: "person.merged", auditable: survivor)
  end

  it "refuses when both people can sign in" do
    create(:user, person: survivor)
    create(:user, person: duplicate, email_address: "other@example.com")
    expect { merge! }.to raise_error(Person::Merge::Error, /Both people have login accounts/)
    expect(duplicate.reload).not_to be_merged
  end

  it "refuses to merge someone into themselves or merge twice" do
    expect { described_class.new(survivor:, duplicate: survivor).merge! }.to raise_error(Person::Merge::Error)
    merge!
    expect { described_class.new(survivor:, duplicate: duplicate.reload).merge! }.to raise_error(Person::Merge::Error, /already been merged/)
  end
end
