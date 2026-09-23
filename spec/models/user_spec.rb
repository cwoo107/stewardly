require "rails_helper"

RSpec.describe User do
  it_behaves_like "a tenant-scoped model"

  it "belongs to exactly one person" do
    user = create(:user)
    expect(build(:user, person: user.person)).not_to be_valid
  end

  it "can't be linked to another church's person" do
    foreign_person = ActsAsTenant.with_tenant(create(:church)) { create(:person) }
    expect(build(:user, person: nil, person_id: foreign_person.id, email_address: "x@example.com")).not_to be_valid
  end

  it "keeps email addresses unique within a church" do
    create(:user, email_address: "sam@example.com")
    expect(build(:user, email_address: "SAM@example.com")).not_to be_valid
  end

  it "allows the same email address at another church" do
    create(:user, email_address: "sam@example.com")
    other = ActsAsTenant.with_tenant(create(:church)) { create(:user, email_address: "sam@example.com") }
    expect(other).to be_persisted
  end

  describe "#can?" do
    it "is granted by any of the user's roles" do
      user = create(:user, roles: [ create(:role, permissions: %w[ view_audit_log ]), create(:role) ])

      expect(user.can?(:view_audit_log)).to be(true)
      expect(user.can?(:manage_users)).to be(false)
    end

    it "grants everything through a grants_all role" do
      user = create(:user, :church_admin)
      expect(Permission.keys.map { |key| user.can?(key) }).to all(be(true))
    end

    it "is false without roles" do
      expect(create(:user).can?(:manage_users)).to be(false)
    end

    it "raises on permission keys that don't exist, so typos fail loudly" do
      expect { create(:user).can?(:manage_everything) }.to raise_error(Permission::UnknownPermission)
    end
  end

  it "audits its deletion" do
    user = create(:user)
    expect { user.destroy! }.to change(AuditEvent, :count).by(1)
    expect(AuditEvent.last).to have_attributes(action: "user.deleted", auditable_id: user.id)
  end
end
