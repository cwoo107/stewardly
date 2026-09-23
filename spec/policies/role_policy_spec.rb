require "rails_helper"

RSpec.describe RolePolicy do
  it "is limited to users who manage users" do
    role = create(:role)
    expect(described_class.new(create(:user, :church_admin), role).show?).to be(true)
    expect(described_class.new(create(:user, :staff), role).show?).to be(false)
  end

  it "scopes to nothing for others" do
    create(:role)
    expect(described_class::Scope.new(create(:user, :member), Role).resolve).to be_empty
  end
end
