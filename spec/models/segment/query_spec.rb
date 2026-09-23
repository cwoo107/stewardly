require "rails_helper"

RSpec.describe Segment::Query do
  def people(*conditions, match: "all")
    described_class.new(match:, conditions:).people
  end

  let!(:ann) { create(:person, first_name: "Ann") }
  let!(:ben) { create(:person, first_name: "Ben") }
  let!(:cal) { create(:person, first_name: "Cal") }

  it "returns everyone (unmerged) with no conditions" do
    ben.update!(merged_into: ann)
    expect(people).to contain_exactly(ann, cal)
  end

  describe "tag" do
    let(:volunteer) { create(:tag) }
    let(:parent) { create(:tag) }

    before do
      ann.tags << [ volunteer, parent ]
      ben.tags << volunteer
    end

    it "matches any, all, or none of the tags" do
      ids = [ volunteer.id, parent.id ]
      expect(people({ type: "tag", tag_ids: ids, operator: "any" })).to contain_exactly(ann, ben)
      expect(people({ type: "tag", tag_ids: ids, operator: "all" })).to contain_exactly(ann)
      expect(people({ type: "tag", tag_ids: ids, operator: "none" })).to contain_exactly(cal)
    end
  end

  it "filters by membership status" do
    ann.update!(membership_status: "member")
    expect(people({ type: "membership_status", statuses: %w[ member ] })).to contain_exactly(ann)
  end

  describe "group" do
    let(:study) { create(:group, group_type: "bible_study") }

    before { create(:group_membership, group: study, person: ann) }

    it "matches people in any group, a group type, or specific groups" do
      small = create(:group, group_type: "small_group")
      create(:group_membership, group: small, person: ben)

      expect(people({ type: "group" })).to contain_exactly(ann, ben)
      expect(people({ type: "group", group_type: "bible_study" })).to contain_exactly(ann)
      expect(people({ type: "group", group_ids: [ small.id ] })).to contain_exactly(ben)
      expect(people({ type: "group", operator: "not_in" })).to contain_exactly(cal)
    end

    it "ignores inactive groups" do
      study.update!(active: false)
      expect(people({ type: "group" })).to be_empty
    end
  end

  it "filters by team membership" do
    create(:team_membership, person: cal)
    expect(people({ type: "team" })).to contain_exactly(cal)
    expect(people({ type: "team", operator: "not_in" })).to contain_exactly(ann, ben)
  end

  it "filters by age as of today in the church's time zone" do
    travel_to Time.utc(2026, 9, 21, 3, 0) do # Sep 20 in Chicago
      ann.update!(birthdate: Date.new(2008, 9, 21)) # turns 18 tomorrow (local)
      ben.update!(birthdate: Date.new(2008, 9, 20)) # 18 today
      cal.update!(birthdate: Date.new(1960, 1, 1))

      expect(people({ type: "age", min: 18, max: 30 })).to contain_exactly(ben)
      expect(people({ type: "age", max: 17 })).to contain_exactly(ann)
    end
  end

  it "matches custom field values, including multi-select choices" do
    create(:custom_field, :select, key: "size")
    create(:custom_field, key: "gifts", field_type: "multi_select", options: %w[ music teaching ])
    ann.update!(custom_field_values: { "size" => "M", "gifts" => %w[ music teaching ] })
    ben.update!(custom_field_values: { "size" => "L", "gifts" => %w[ teaching ] })

    expect(people({ type: "custom_field", key: "size", value: "M" })).to contain_exactly(ann)
    expect(people({ type: "custom_field", key: "gifts", value: "teaching" })).to contain_exactly(ann, ben)
  end

  it "matches people whose household is within a distance of a campus (PostGIS)" do
    campus = create(:campus, :with_location, latitude: 36.1627, longitude: -86.7816)
    ann.update!(household: create(:household, :with_location, latitude: 36.17, longitude: -86.78)) # ~0.5 mi
    ben.update!(household: create(:household, :with_location, latitude: 36.30, longitude: -86.60)) # ~13 mi

    expect(people({ type: "distance", campus_id: campus.id, miles: 3 })).to contain_exactly(ann)
    expect(people({ type: "distance", latitude: 36.30, longitude: -86.60, miles: 1 })).to contain_exactly(ben)
  end

  it "finds people with no touchpoint in N days" do
    create(:touchpoint, person: ann, occurred_at: 3.days.ago)
    create(:touchpoint, person: ben, occurred_at: 60.days.ago)
    expect(people({ type: "no_touchpoint", days: 30 })).to contain_exactly(ben, cal)
  end

  it "combines conditions with all or any" do
    ann.update!(membership_status: "member")
    create(:touchpoint, person: ann)
    member = { type: "membership_status", statuses: %w[ member ] }
    quiet = { type: "no_touchpoint", days: 30 }

    expect(people(member, quiet, match: "all")).to be_empty
    expect(people(member, quiet, match: "any")).to contain_exactly(ann, ben, cal)
  end

  it "skips invalid conditions instead of failing" do
    expect(people({ type: "age" }, { type: "nonsense" })).to contain_exactly(ann, ben, cal)
  end

  it "runs as a single SQL query" do
    create(:custom_field, :select, key: "size")
    create(:campus, :with_location)
    conditions = [ { type: "tag", tag_ids: [ create(:tag).id ], operator: "all" }, { type: "group" }, { type: "team" },
      { type: "age", min: 1 }, { type: "custom_field", key: "size", value: "M" },
      { type: "distance", campus_id: Campus.last.id, miles: 5 }, { type: "no_touchpoint", days: 5 } ]
    relation = people(*conditions, match: "any")

    queries = []
    counter = ->(*, payload) { queries << payload[:sql] unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { relation.to_a }
    expect(queries.size).to eq(1)
  end

  it "never reaches into another church" do
    other_tag = ActsAsTenant.with_tenant(create(:church)) do
      tag = create(:tag)
      create(:tagging, tag:)
      tag
    end
    expect(people({ type: "tag", tag_ids: [ other_tag.id ] })).to be_empty
  end
end
