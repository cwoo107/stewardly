require "rails_helper"

RSpec.describe "Merging duplicates" do
  it "reviews a suggested pair and merges it" do
    create(:person, first_name: "Sam", last_name: "Lee", email: "sam@example.com")
    create(:person, first_name: "Samuel", last_name: "Lee", email: "sam@example.com", phone: "555-0100")
    sign_in_as(create(:user, :staff))

    visit duplicates_path
    click_on "Review merge"
    click_on "Merge"

    expect(page).to have_content("Merged Samuel Lee into Sam Lee.")
    expect(page).to have_content("555-0100")
    visit duplicates_path
    expect(page).to have_content("No likely duplicates")
  end
end
