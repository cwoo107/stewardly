require "rails_helper"

RSpec.describe "Managing roles" do
  it "lets a church admin grant and revoke a role, and see it in the audit log" do
    admin = create(:user, :church_admin)
    create(:role, key: "staff", name: "Staff")
    volunteer = create(:user, person: create(:person, first_name: "Riley", last_name: "Nguyen"))

    sign_in_as(admin)
    click_on "Users", match: :first
    click_on "Riley Nguyen"

    select "Staff", from: "Grant a role"
    click_on "Grant"
    expect(page).to have_content("Granted Staff.")
    within("#user_roles") { expect(page).to have_content("Staff") }

    click_on "Revoke"
    expect(page).to have_content("Revoked Staff.")

    click_on "Audit log", match: :first
    expect(page).to have_content("granted Staff to Riley Nguyen")
    expect(page).to have_content("revoked Staff from Riley Nguyen")
    expect(volunteer.reload.roles).to be_empty
  end
end
