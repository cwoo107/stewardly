require "rails_helper"

RSpec.describe "Audit log" do
  it "shows this church's events to church admins" do
    admin = create(:user, :church_admin)
    create(:user_role, user: create(:user), role: create(:role, name: "Greeters"))
    ActsAsTenant.with_tenant(create(:church)) { create(:audit_event, action: "user.deleted", metadata: { email_address: "secret@else.where" }) }
    sign_in_as(admin)

    get audit_events_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("granted Greeters")
    expect(response.body).not_to include("secret@else.where")
  end

  it "pages through older events" do
    user = create(:user, :church_admin)
    51.times { create(:audit_event, auditable: user) }
    sign_in_as(user)

    get audit_events_path
    expect(response.body).to include("Older")

    get audit_events_path(page: 2)
    expect(response.body).to include("Newer")
  end

  it "is forbidden without view_audit_log" do
    sign_in_as(create(:user, :staff))
    get audit_events_path
    expect(response).to have_http_status(:forbidden)
  end
end
