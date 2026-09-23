require "rails_helper"

RSpec.describe "Sidebar sections", :js do
  it "expand and collapse, and remember what was opened" do
    page.driver.resize(1400, 1000)
    sign_in_as(create(:user, :church_admin))

    within("aside") do
      expect(page).to have_no_link("Households")
      find("summary", text: "PEOPLE").click
      expect(page).to have_link("Households")
    end

    visit calendar_path
    within("aside") { expect(page).to have_link("Households") } # remembered

    within("aside") { find("summary", text: "PEOPLE").click }
    visit calendar_path
    within("aside") { expect(page).to have_no_link("Households") }
  end
end
