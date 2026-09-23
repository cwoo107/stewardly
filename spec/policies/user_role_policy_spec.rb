require "rails_helper"

RSpec.describe UserRolePolicy do
  let(:target) { create(:user) }
  let(:staff_role) { create(:role, key: "greeters") }
  let(:admin_role) { Role.find_by(key: "church_admin") || create(:role, key: "church_admin", grants_all: true) }

  it "lets church admins grant any role, including church admin" do
    admin = create(:user, :church_admin)
    expect(described_class.new(admin, UserRole.new(user: target, role: staff_role)).create?).to be(true)
    expect(described_class.new(admin, UserRole.new(user: target, role: admin_role)).create?).to be(true)
  end

  it "stops non-admins with manage_users from granting church admin" do
    manager = create(:user, roles: [ create(:role, permissions: %w[ manage_users ]) ])

    expect(described_class.new(manager, UserRole.new(user: target, role: staff_role)).create?).to be(true)
    expect(described_class.new(manager, UserRole.new(user: target, role: admin_role)).create?).to be(false)
    expect(described_class.new(manager, UserRole.new(user: target, role: admin_role)).destroy?).to be(false)
  end

  it "denies users without manage_users" do
    expect(described_class.new(create(:user, :staff), UserRole.new(user: target, role: staff_role)).create?).to be(false)
  end
end
