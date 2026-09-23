require "rails_helper"

RSpec.describe Role do
  it_behaves_like "a tenant-scoped model"

  it "keeps keys unique within a church only" do
    create(:role, key: "greeters")
    expect(build(:role, key: "greeters")).not_to be_valid
    expect(ActsAsTenant.with_tenant(create(:church)) { build(:role, key: "greeters").valid? }).to be(true)
  end

  it "only accepts permissions from the catalogue" do
    role = build(:role, permissions: %w[ manage_users launch_rockets ])
    expect(role).not_to be_valid
    expect(role.errors[:permissions].first).to include("launch_rockets")
  end

  it "normalizes permissions" do
    expect(build(:role, permissions: [ "view_audit_log", "", "manage_users", "view_audit_log" ]).permissions)
      .to eq(%w[ manage_users view_audit_log ])
  end

  describe "#grants?" do
    it "grants listed permissions" do
      role = build(:role, permissions: %w[ manage_users ])
      expect(role.grants?(:manage_users)).to be(true)
      expect(role.grants?(:view_audit_log)).to be(false)
    end

    it "grants everything when grants_all is set" do
      expect(build(:role, grants_all: true).grants?(:view_audit_log)).to be(true)
    end
  end

  it "can't delete default (system) roles" do
    role = create(:role, system: true)
    expect(role.destroy).to be(false)
    expect(role.errors[:base]).to include("Default roles can't be deleted")
  end

  it "can't be deleted while users hold it" do
    role = create(:role)
    create(:user, roles: [ role ])
    expect(role.destroy).to be(false)
  end
end
