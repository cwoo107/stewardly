require "rails_helper"

RSpec.describe Platform::ChurchPolicy do
  it "admits platform admins" do
    policy = described_class.new(build(:platform_admin), Church)
    expect([ policy.index?, policy.new?, policy.create? ]).to all(be(true))
  end

  it "denies church users, even church admins" do
    policy = described_class.new(create(:user, :church_admin), Church)
    expect([ policy.index?, policy.create? ]).to all(be(false))
    expect(described_class::Scope.new(create(:user, :church_admin), Church).resolve).to be_empty
  end
end
