require "rails_helper"

RSpec.describe "People" do
  let(:staff) { create(:user, :staff) }
  let!(:ada) { create(:person, first_name: "Ada", last_name: "Lovelace", email: "ada@example.com") }

  context "as staff" do
    before { sign_in_as(staff) }

    it "lists, searches, and filters people" do
      tag = create(:tag, name: "Volunteer")
      ada.tags << tag
      create(:person, first_name: "Bob", last_name: "Smith")

      get people_path
      expect(response.body).to include("Ada Lovelace", "Bob Smith")

      get people_path(q: "love")
      expect(response.body).to include("Ada Lovelace")
      expect(response.body).not_to include("Bob Smith")

      get people_path(tag_id: tag.id)
      expect(response.body).not_to include("Bob Smith")
    end

    it "filters by a saved segment" do
      ada.update!(membership_status: "member")
      segment = create(:segment, definition: { conditions: [ { type: "membership_status", statuses: [ "member" ] } ] })
      create(:person, first_name: "Guest", last_name: "Person")

      get people_path(segment_id: segment.id)
      expect(response.body).to include("Ada Lovelace")
      expect(response.body).not_to include("Guest Person")
    end

    it "shows a profile with its timeline, but hides sensitive notes from staff" do
      create(:touchpoint, person: ada, summary: "Coffee chat", body: "Talked about her new job")
      create(:touchpoint, person: ada, summary: "Prayer follow-up", body: "Private prayer details", sensitive: true, kind: "prayer_follow_up")

      get person_path(ada)

      expect(response.body).to include("Coffee chat", "Talked about her new job", "Prayer follow-up")
      expect(response.body).not_to include("Private prayer details")
    end

    it "creates a person with tags and custom fields" do
      tag = create(:tag)
      create(:custom_field, :select, key: "size")

      post people_path, params: { person: { first_name: "Grace", last_name: "Hopper", tag_ids: [ tag.id ], custom_field_values: { size: "M" } } }

      grace = Person.find_by!(first_name: "Grace")
      expect(response).to redirect_to(grace)
      expect(grace.tags).to contain_exactly(tag)
      expect(grace.custom_fields).to eq("size" => "M")
    end

    it "shows validation errors" do
      post people_path, params: { person: { first_name: "" } }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "deletes a person and audits it" do
      delete person_path(ada)
      expect(Person.exists?(ada.id)).to be(false)
      expect(AuditEvent.last).to have_attributes(action: "person.deleted", actor: staff)
    end

    it "logs a contact on the timeline" do
      post person_touchpoints_path(ada), params: { touchpoint: { kind: "call", summary: "Checked in", body: "Doing well" } }
      expect(ada.touchpoints.sole).to have_attributes(kind: "call", author: staff, body: "Doing well")
    end

    it "won't log system-only kinds by hand" do
      post person_touchpoints_path(ada), params: { touchpoint: { kind: "workflow_message", summary: "Fake" } }
      expect(ada.touchpoints).to be_empty
    end

    it "can't see another church's people or merged records" do
      outsider = ActsAsTenant.with_tenant(create(:church)) { create(:person) }
      merged = create(:person, merged_into: ada)

      get person_path(outsider)
      expect(response).to have_http_status(:not_found)
      get person_path(merged)
      expect(response).to have_http_status(:not_found)
    end
  end

  it "lets the care team read but not edit" do
    sign_in_as(create(:user, :care_team))
    get person_path(ada)
    expect(response).to have_http_status(:ok)
    patch person_path(ada), params: { person: { first_name: "Changed" } }
    expect(response).to have_http_status(:forbidden)
  end

  it "keeps members out" do
    sign_in_as(create(:user, :member))
    get people_path
    expect(response).to have_http_status(:forbidden)
  end

  describe "search for adding members" do
    it "offers Add buttons for a group the leader manages" do
      leader = create(:user, :member)
      ministry = create(:ministry)
      create(:ministry_leadership, ministry:, user: leader)
      group = create(:group, ministry:)
      sign_in_as(leader)

      get search_people_path(q: "Ada", for: "group:#{group.id}")

      expect(response.body).to include("Ada Lovelace", group_group_memberships_path(group))
    end
  end
end
