require "rails_helper"

RSpec.describe "Ministries, groups, and teams" do
  let(:ministry) { create(:ministry, name: "Worship") }
  let(:other_ministry) { create(:ministry, name: "Kids") }
  let(:leader) { create(:user, :member).tap { |user| create(:ministry_leadership, ministry:, user:) } }
  let(:person) { create(:person, first_name: "Ada", last_name: "Lovelace") }

  context "as a ministry leader" do
    before { sign_in_as(leader) }

    it "sees only the ministries they lead" do
      other_ministry
      get ministries_path
      expect(response.body).to include("Worship")
      expect(response.body).not_to include("Kids")
      get ministry_path(other_ministry)
      expect(response).to have_http_status(:not_found)
    end

    it "creates groups in their ministry but not others" do
      post groups_path, params: { group: { name: "Choir study", ministry_id: ministry.id } }
      expect(Group.find_by!(name: "Choir study").ministry).to eq(ministry)

      post groups_path, params: { group: { name: "Sneaky", ministry_id: other_ministry.id } }
      expect(response).to have_http_status(:forbidden)
    end

    it "can't move a group into a ministry they don't lead" do
      group = create(:group, ministry:)
      patch group_path(group), params: { group: { ministry_id: other_ministry.id } }
      expect(response).to have_http_status(:forbidden)
      expect(group.reload.ministry).to eq(ministry)
    end

    it "adds and removes group members, and promotes leaders" do
      group = create(:group, ministry:)
      post group_group_memberships_path(group), params: { group_membership: { person_id: person.id } }
      membership = group.group_memberships.sole

      patch group_group_membership_path(group, membership), params: { group_membership: { role: "leader" } }
      expect(membership.reload).to be_leader

      get group_path(group)
      expect(response.body).to include("Ada Lovelace", "Leader")

      delete group_group_membership_path(group, membership)
      expect(group.group_memberships).to be_empty
    end

    it "manages team positions and members" do
      team = create(:team, ministry:)
      post team_positions_path(team), params: { position: { name: "Drums" } }
      post team_team_memberships_path(team), params: { team_membership: { person_id: person.id } }
      get team_path(team)
      expect(response.body).to include("Drums", "Ada Lovelace")
    end

    it "can't touch another ministry's team" do
      team = create(:team, ministry: other_ministry)
      post team_team_memberships_path(team), params: { team_membership: { person_id: person.id } }
      expect(response).to have_http_status(:forbidden)
    end

    it "can't appoint other leaders" do
      post ministry_ministry_leaderships_path(ministry), params: { ministry_leadership: { user_id: create(:user).id } }
      expect(response).to have_http_status(:forbidden)
    end
  end

  context "as staff (manage_ministries)" do
    before { sign_in_as(create(:user, :staff)) }

    it "creates ministries and appoints leaders" do
      post ministries_path, params: { ministry: { name: "Hospitality" } }
      hospitality = Ministry.find_by!(name: "Hospitality")
      user = create(:user)

      post ministry_ministry_leaderships_path(hospitality), params: { ministry_leadership: { user_id: user.id } }

      expect(hospitality.leaders).to contain_exactly(user)
      expect(AuditEvent.last.action).to eq("ministry_leader.added")
    end

    it "filters groups" do
      create(:group, name: "Tuesday Study", group_type: "bible_study")
      create(:group, name: "Young Families", group_type: "small_group")
      get groups_path(group_type: "bible_study")
      expect(response.body).to include("Tuesday Study")
      expect(response.body).not_to include("Young Families")
    end

    it "won't overfill a group" do
      group = create(:group, capacity: 1)
      create(:group_membership, group:)
      post group_group_memberships_path(group), params: { group_membership: { person_id: person.id } }
      follow_redirect!
      expect(response.body).to include("is full")
    end
  end
end
