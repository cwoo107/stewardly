require "rails_helper"

RSpec.describe "Building a segment", :js do
  it "adds conditions, shows a live count, and saves" do
    volunteer = create(:tag, name: "Volunteer")
    create(:person, first_name: "Vera", last_name: "Volunteer").tags << volunteer
    create(:person, first_name: "Nora", last_name: "Nobody")
    sign_in_as(create(:user, :staff))

    visit new_segment_path
    fill_in "Name", with: "Volunteers"
    select "Tags", from: "Add a condition"
    click_on "Add"
    check "Volunteer"

    within("#segment_preview") { expect(page).to have_content("1 person").and have_content("Vera Volunteer") }

    click_on "Save segment"
    expect(page).to have_content("Segment saved.")
    expect(page).to have_content("Tagged any of: Volunteer")
    expect(Segment.last.people).to contain_exactly(Person.find_by!(first_name: "Vera"))
  end
end
