require "rails_helper"

RSpec.describe UserRole do
  it_behaves_like "a tenant-scoped model"

  context "with a signed-in church admin" do
    let(:actor) { create(:user, :church_admin) }

    before { Current.session = build(:session, user: actor) }

    it "can't grant the same role twice" do
      user_role = create(:user_role)
      expect(build(:user_role, user: user_role.user, role: user_role.role)).not_to be_valid
    end

    it "can't use another church's role" do
      foreign_role = ActsAsTenant.with_tenant(create(:church)) { create(:role) }
      expect(build(:user_role, role_id: foreign_role.id)).not_to be_valid
    end

    it "can't grant a role to another church's user" do
      foreign_user = ActsAsTenant.with_tenant(create(:church)) { create(:user) }
      expect(build(:user_role, user_id: foreign_user.id)).not_to be_valid
    end

    it "audits grants with the acting user" do
      user = create(:user)
      role = create(:role, name: "Greeters")

      expect { create(:user_role, user:, role:) }.to change(AuditEvent, :count).by(1)
      expect(AuditEvent.last).to have_attributes(action: "role.granted", actor:, auditable: user)
      expect(AuditEvent.last.metadata).to include("role_name" => "Greeters", "user_name" => user.name)
    end

    it "audits revocations" do
      user_role = create(:user_role)
      expect { user_role.destroy! }.to change(AuditEvent, :count).by(1)
      expect(AuditEvent.last.action).to eq("role.revoked")
    end

    it "won't revoke the church's last church admin" do
      admin_grant = actor.user_roles.sole

      expect(admin_grant.destroy).to be(false)
      expect(admin_grant.errors[:base]).to include("A church must keep at least one church admin")
    end

    it "revokes church admin when another admin remains" do
      create(:user, :church_admin)
      expect(actor.user_roles.sole.destroy).to be_truthy
    end
  end
end
