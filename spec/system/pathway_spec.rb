require "rails_helper"

RSpec.describe "Pathway", :js do
  before { page.driver.resize(1400, 1000) }

  it "edits a stage's rules with a live preview and shows the dashboard" do
    create(:group_membership)
    create(:person)
    Pathway::Placement.new(Pathway.current).place_everyone!
    sign_in_as(create(:user, :staff))

    visit edit_pathway_path
    within("li", text: "Grow") { click_on "Edit" }
    within("#segment_preview") { expect(page).to have_content("Grow") }

    select "Attended services", from: "Add a rule"
    click_on "Add"
    expect(page).to have_field("At least this many times")
    click_on "Save stage"
    expect(page).to have_content("Grow saved")

    visit pathway_path
    expect(page).to have_content("People at each stage")
    expect(page).to have_css("canvas", minimum: 2)
  end
end
