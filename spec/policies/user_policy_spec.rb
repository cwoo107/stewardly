require "rails_helper"

RSpec.describe UserPolicy do
  let(:admin) { create(:user, :church_admin) }
  let(:member) { create(:user, :member) }

  it "lets users with manage_users see and remove other users" do
    policy = described_class.new(admin, member)
    expect([ policy.index?, policy.show?, policy.destroy? ]).to all(be(true))
  end

  it "stops anyone removing their own account" do
    expect(described_class.new(admin, admin).destroy?).to be(false)
  end

  it "denies members" do
    policy = described_class.new(member, admin)
    expect([ policy.index?, policy.show?, policy.destroy? ]).to all(be(false))
  end

  describe "scope" do
    it "returns everyone for managers and only themselves otherwise" do
      admin && member
      expect(described_class::Scope.new(admin, User).resolve).to contain_exactly(admin, member)
      expect(described_class::Scope.new(member, User).resolve).to contain_exactly(member)
    end
  end
end
