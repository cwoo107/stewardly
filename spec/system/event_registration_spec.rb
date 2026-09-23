require "rails_helper"

RSpec.describe "Event registration and check-in" do
  before { stub_const("PublicSubmissionProtection::MINIMUM_FILL_TIME", 0.seconds) }

  it "registers a guest, waitlists the next one, and checks people in" do
    event = create(:event, :registration, title: "Newcomer lunch", capacity: 1)
    create(:event_occurrence, event:)
    visit_church(church)

    visit public_event_path(event.slug)
    fill_in "First name", with: "Ada"
    fill_in "Last name", with: "Lovelace"
    fill_in "Email", with: "ada@example.com"
    click_on "Register"
    expect(page).to have_content("You're registered.")

    visit public_event_path(event.slug)
    expect(page).to have_content("Full: you can join the waitlist.")
    fill_in "First name", with: "Bo"
    fill_in "Last name", with: "Diddley"
    fill_in "Email", with: "bo@example.com"
    click_on "Join the waitlist"
    expect(page).to have_content("You're on the waitlist.")

    sign_in_as(create(:user, :staff))
    visit edit_event_path(event)
    click_on "Check in", match: :first
    within("li", text: "Ada Lovelace") { click_on "Check in" }
    expect(page).to have_content(/checked in/i)
    expect(Registration.confirmed.sole).to be_checked_in
  end
end
