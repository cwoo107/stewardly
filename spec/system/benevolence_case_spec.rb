require "rails_helper"

RSpec.describe "A benevolence case from request to payment" do
  it "opens, approves, and pays a request" do
    church.update!(benevolence_approval_threshold_cents: 50_000)
    create(:fund, :benevolence, name: "Care fund")
    person = create(:person, first_name: "Sam", last_name: "Ortiz")
    sign_in_as(create(:user, :church_admin))

    visit new_benevolence_case_path(person_id: person.id)
    select "Utilities", from: "Kind of need"
    fill_in "Amount requested", with: "220"
    fill_in "What do they need help with?", with: "Power bill past due"
    click_on "Open case"
    expect(page).to have_content("Utilities for Sam Ortiz")

    fill_in "Amount to approve", with: "200"
    click_on "Approve"
    expect(page).to have_content("Your approval is recorded")
    expect(page).to have_content("Approved")

    select "Utility company", from: "Paid to"
    fill_in "Payee name", with: "City Power"
    select "Care fund", from: "Fund"
    click_on "Record payment"
    expect(page).to have_content("Payment of $200.00 recorded")
    expect(page).to have_content("Fulfilled")
  end
end
