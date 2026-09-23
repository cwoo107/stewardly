require "rails_helper"

RSpec.describe "Member home on a phone", :js do
  it "fits the screen and uses the bottom navigation" do
    create(:announcement, title: "Fall kickoff")
    page.driver.resize(390, 844)
    sign_in_as(create(:user, :member))

    expect(page).to have_content("Fall kickoff")
    overflow = page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
    expect(overflow).to be <= 0
    within("nav.fixed") { click_on "Serving" }
    expect(page).to have_content("My schedule")
  end
end
