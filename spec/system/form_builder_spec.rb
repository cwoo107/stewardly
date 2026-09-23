require "rails_helper"

RSpec.describe "Building a form", :js do
  it "adds questions, a show/hide condition, and publishes" do
    sign_in_as(create(:user, :staff))

    visit new_form_path
    fill_in "Name", with: "Volunteer interest"
    click_on "Create form"
    expect(page).to have_content("Form created")

    select "Checkbox", from: "Add a question"
    click_on "Add"
    fill_in "Question", with: "I'd like to serve"
    click_on "Save question"
    expect(page).to have_content("I'd like to serve")

    select "Paragraph", from: "Add a question"
    click_on "Add"
    within("#form_fields li:last-child") do
      fill_in "Question", with: "Where would you like to serve?"
      select "I'd like to serve", from: "Condition 1 question"
      select "is filled in", from: "Condition 1 comparison"
      click_on "Save question"
      expect(page).to have_content("Shown when I'd like to serve is filled in")
    end

    click_on "Publish"
    expect(page).to have_content("Published")
    form = Form.find_by!(slug: "volunteer-interest")
    expect(form.fields.map(&:label)).to eq([ "I'd like to serve", "Where would you like to serve?" ])
  end

  it "reorders questions by dragging" do
    form = create(:form)
    create(:form_field, form:, label: "First question")
    create(:form_field, form: form.reload, label: "Second question")
    sign_in_as(create(:user, :staff))

    visit edit_form_path(form)
    find("#form_fields li", text: "Second question").drag_to(find("#form_fields li", text: "First question"))

    expect { form.fields.reload.map(&:label) }.to eventually_eq([ "Second question", "First question" ])
  end
end
