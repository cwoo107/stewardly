require "rails_helper"

RSpec.describe "Filling in a public form", :js do
  before { stub_const("PublicSubmissionProtection::MINIMUM_FILL_TIME", 0.seconds) }

  it "shows follow-up questions as answers change and submits" do
    form = create(:form, :connect_card, name: "Connect card", confirmation_message: "Welcome!")
    visit_church(church)

    visit public_form_path(form.slug)
    expect(page).to have_no_field("How did you hear about us?")

    check "First visit"
    expect(page).to have_select("How did you hear about us?")
    uncheck "First visit"
    expect(page).to have_no_select("How did you hear about us?")
    check "First visit"

    fill_in "First name", with: "Ada"
    fill_in "Last name", with: "Lovelace"
    fill_in "Email", with: "ada@example.com"
    select "A friend", from: "How did you hear about us?"
    click_on "Submit"

    expect(page).to have_content("Welcome!")
    expect(FormSubmission.sole.answers).to include("heard" => "A friend", "first_visit" => true)
  end
end
