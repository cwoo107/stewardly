require "rails_helper"

RSpec.describe "Member area" do
  let(:user) { create(:user, :member) }

  it "lets a volunteer accept a request from home" do
    service = create(:worship_service, name: "Sunday 9am")
    occurrence = create(:service_occurrence, worship_service: service, local_date: church.today + 7)
    create(:assignment, schedulable: occurrence, person: user.person, position: create(:position, name: "Door"))

    sign_in_as(user)
    expect(page).to have_content("Can you serve?")
    click_on "I'll serve"
    expect(page).to have_content("Thanks for serving!")
    expect(page).to have_content("You're serving")
  end

  it "enrolls in a class" do
    create(:course_offering, course: create(:course, name: "Membership 101"))
    sign_in_as(user)
    click_on "Classes", match: :first
    click_on "Enroll"
    expect(page).to have_content("You're enrolled!")
    within("section", text: "My classes") { expect(page).to have_content("Membership 101") }
  end

  it "asks to join a group, and a leader approves" do
    group = create(:group, name: "Tuesday Study")
    leader = create(:user, :member)
    create(:group_membership, group:, person: leader.person, role: "leader")

    sign_in_as(user)
    visit member_group_path(group)
    fill_in "Anything the leader should know? (optional)", with: "We're new"
    click_on "Ask to join"
    expect(page).to have_content("Request sent")

    click_on "Sign out", match: :first
    sign_in_as(leader)
    visit group_path(group)
    click_on "Approve"
    expect(page).to have_content("request was approved")
    expect(group.people).to include(user.person)
  end
end
