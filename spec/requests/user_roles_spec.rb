require "rails_helper"

RSpec.describe "Granting and revoking roles" do
  let(:admin) { create(:user, :church_admin) }
  let(:target) { create(:user) }
  let(:staff_role) { create(:role, key: "greeters", name: "Greeters") }

  context "as a church admin" do
    before { sign_in_as(admin) }

    it "grants a role and audits it" do
      post user_user_roles_path(target), params: { user_role: { role_id: staff_role.id } }

      expect(response).to redirect_to(user_path(target))
      expect(target.reload.roles).to contain_exactly(staff_role)
      expect(AuditEvent.last).to have_attributes(action: "role.granted", actor: admin, auditable: target)
    end

    it "revokes a role and audits it" do
      grant = create(:user_role, user: target, role: staff_role)

      delete user_user_role_path(target, grant)

      expect(target.reload.roles).to be_empty
      expect(AuditEvent.last).to have_attributes(action: "role.revoked", actor: admin)
    end

    it "refuses to revoke the last church admin" do
      delete user_user_role_path(admin, admin.user_roles.sole)

      expect(response).to redirect_to(user_path(admin))
      expect(flash[:alert]).to include("at least one church admin")
      expect(admin.reload).to be_church_admin
    end

    it "cannot grant another church's role" do
      foreign_role = ActsAsTenant.with_tenant(create(:church)) { create(:role) }
      post user_user_roles_path(target), params: { user_role: { role_id: foreign_role.id } }
      expect(response).to have_http_status(:not_found)
    end
  end

  it "stops a user manager who isn't a church admin from granting church admin" do
    manager = create(:user, roles: [ create(:role, permissions: %w[ manage_users ]) ])
    admin # ensure the church admin role exists
    sign_in_as(manager)

    post user_user_roles_path(manager), params: { user_role: { role_id: Role.find_by!(key: "church_admin").id } }

    expect(response).to have_http_status(:forbidden)
    expect(manager.reload).not_to be_church_admin
  end

  it "is forbidden to staff" do
    sign_in_as(create(:user, :staff))
    post user_user_roles_path(target), params: { user_role: { role_id: staff_role.id } }
    expect(response).to have_http_status(:forbidden)
    expect(target.reload.roles).to be_empty
  end
end
