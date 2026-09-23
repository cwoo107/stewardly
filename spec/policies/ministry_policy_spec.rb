require "rails_helper"

RSpec.describe MinistryPolicy do
  let(:mine) { create(:ministry) }
  let(:theirs) { create(:ministry) }
  let(:leader) { create(:user, :member).tap { |user| create(:ministry_leadership, user:, ministry: mine) } }

  it "lets a leader see and update only their own ministry" do
    expect(described_class.new(leader, mine).update?).to be(true)
    expect(described_class.new(leader, theirs).show?).to be(false)
    expect(described_class.new(leader, mine).destroy?).to be(false)
    expect(described_class::Scope.new(leader, Ministry).resolve).to contain_exactly(mine)
  end

  it "gives manage_ministries every ministry" do
    staff = create(:user, :staff)
    expect([ described_class.new(staff, theirs).update?, described_class.new(staff, Ministry).create? ]).to all(be(true))
  end

  describe GroupPolicy do
    it "lets a leader manage groups in their ministry only" do
      expect(GroupPolicy.new(leader, build(:group, ministry: mine)).update?).to be(true)
      expect(GroupPolicy.new(leader, build(:group, ministry: theirs)).update?).to be(false)
      expect(GroupPolicy.new(leader, build(:group, ministry: nil)).create?).to be(false)
    end

    it "scopes a leader's groups to their ministries" do
      own = create(:group, ministry: mine)
      create(:group, ministry: theirs)
      expect(GroupPolicy::Scope.new(leader, Group).resolve).to contain_exactly(own)
    end
  end

  describe TeamPolicy do
    it "follows the team's ministry" do
      expect(TeamPolicy.new(leader, build(:team, ministry: mine)).update?).to be(true)
      expect(TeamPolicy.new(leader, build(:team, ministry: theirs)).update?).to be(false)
    end
  end
end
