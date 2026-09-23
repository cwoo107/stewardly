require "rails_helper"

RSpec.describe "Matching gifts in the review queue", :js do
  it "finds a person with the picker and matches the gift" do
    create(:donation, donor_name: "J. Smith", donor_email: "js@example.com", amount_cents: 4_200)
    create(:person, first_name: "Jordan", last_name: "Smithers")
    sign_in_as(create(:user, :church_admin))

    visit donation_matches_path
    expect(page).to have_content("$42.00")
    fill_in "Find someone else", with: "Smithers"
    click_on "Search"
    within("turbo-frame[id^='person_search_']") { click_on "Match" }
    expect(page).to have_content("Matched to Jordan Smithers")
    expect(page).to have_content("Every gift is matched")
  end
end
