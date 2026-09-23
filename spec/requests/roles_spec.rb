require "rails_helper"

RSpec.describe "Roles" do
  it "lists and shows roles to church admins" do
    admin = create(:user, :church_admin)
    sign_in_as(admin)

    get roles_path
    expect(response.body).to include("Church admin")

    get role_path(admin.roles.sole)
    expect(response.body).to include(Permission.description(:view_audit_log))
  end

  it "is forbidden to members" do
    sign_in_as(create(:user, :member))
    get roles_path
    expect(response).to have_http_status(:forbidden)
  end
end
