require "rails_helper"

RSpec.describe "Building a workflow", :js do
  it "sets a trigger, adds a branch with a step inside, edits steps inline, and publishes" do
    create(:tag, name: "Newcomer")
    staff = create(:user, :staff)
    sign_in_as(staff)

    visit new_workflow_path
    fill_in "Name", with: "Newcomer care"
    click_on "Create workflow"

    select "A tag is added", from: "Start this workflow when"
    select "Newcomer", from: "Tag"
    click_on "Save trigger"
    expect(page).to have_content("Tagged Newcomer")

    select "If / else", from: "Step to add", match: :first
    click_on "+ Add step", match: :first
    within(".rounded-2xl[data-move-url]", match: :first) do
      select "Membership status", from: "Add a rule"
      click_on "Add"
      check "Guest"
      click_on "Save step"
    end
    expect(page).to have_content("If Status is Guest")
    expect(page).to have_no_content("needs at least one rule")

    within(".rounded-2xl[data-move-url]", match: :first) do
      within(:xpath, ".//div[p[contains(., 'If yes')]]") do
        select "Create a task", from: "Step to add"
        click_on "+ Add step"
      end
    end
    fill_in "Task", with: "Welcome {{ person.first_name }}"
    select staff.name, from: "For"
    click_on "Save step"
    expect(page).to have_content("Task for #{staff.name}: Welcome {{ person.first_name }}")

    accept_confirm { click_on "Publish" }
    expect(page).to have_content("Version 1 is live")
    workflow = Workflow.find_by!(name: "Newcomer care")
    expect(workflow).to be_active
    expect(workflow.current_version.parsed_definition.steps.first["yes"].first["type"]).to eq("create_task")
  end
end
