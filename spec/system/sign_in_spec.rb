require "rails_helper"

RSpec.describe "Signing in" do
  it "lets a member sign in to the member area and out again" do
    user = create(:user, :member)

    sign_in_as(user)
    expect(page).to have_current_path(member_root_path)
    expect(page).to have_content("Hi, #{user.person.first_name}")
    expect(page).to have_content(church.name)

    click_on "Sign out", match: :first
    expect(page).to have_content("Sign in to #{church.name}")
  end

  it "takes staff to the admin dashboard" do
    user = create(:user, :staff)
    sign_in_as(user)
    expect(page).to have_content("Welcome, #{user.person.first_name}")
  end

  it "shows an error for a wrong password" do
    sign_in_as(create(:user), password: "wrong")
    expect(page).to have_content("Try another email address or password.")
  end
end
