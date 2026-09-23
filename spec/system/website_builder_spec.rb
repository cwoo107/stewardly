require "rails_helper"

RSpec.describe "Building the website", :js do
  it "adds a section, reorders by dragging, publishes, and the site shows it" do
    Site.current.update!(published: true)
    sign_in_as(create(:user, :staff))

    visit website_path
    click_on "Home", match: :first
    click_on "+ Text"
    fill_in "Heading", with: "Hello neighbors"
    click_on "Save section"
    expect(page).to have_content("Text saved to the draft")

    items = all("[data-move-url]")
    expect(items.last).to have_content("Text")
    items.last.drag_to(items.first)
    expect(page).to have_css("[data-move-url]:first-child", text: "Text", wait: 3)
    expect(Site.current.home_page.reload.section_list.first["key"]).to eq("text")

    click_on "Publish"
    expect(page).to have_content("Published")
    visit "http://#{church.subdomain}.sites.localhost:#{Capybara.server_port}/"
    expect(page).to have_content("Hello neighbors")
  end

  it "edits a section's Liquid in the code editor" do
    sign_in_as(create(:user, :church_admin))
    visit website_sections_path
    within(find("li", text: "Give")) { click_on "Edit code" }
    editor = find(".cm-content", match: :first)
    editor.click
    editor.send_keys([ :control, "a" ], [ :command, "a" ], :backspace, "<section>{{ settings.heading | escape }} (edited)</section>")
    click_on "Save section"
    expect(page).to have_content("Section saved")
    expect(SectionDefinition.kind_web.find_by!(key: "give")).to have_attributes(customized: true, liquid: include("(edited)"))
  end
end
