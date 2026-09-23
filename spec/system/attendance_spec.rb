require "rails_helper"

RSpec.describe "Attendance", :js do
  it "enters Sunday counts and sees them on the dashboard's charts" do
    service = create(:worship_service, name: "Sunday 9am")
    sunday = church.today.sunday? ? church.today : church.today.prev_occurring(:sunday)
    sign_in_as(create(:user, :staff))

    visit attendance_counts_path(date: sunday)
    fill_in "Adults", with: "150"
    fill_in "Kids", with: "40"
    fill_in "Online", with: "60"
    fill_in "First-time guests", with: "5"
    click_on "Save counts"
    expect(page).to have_content("Counts saved.")
    expect(service.occurrences.find_by!(local_date: sunday).attendance_count.total).to eq(250)

    visit attendance_path
    expect(page).to have_css("canvas", minimum: 3) # Chartkick drew the charts
    find("summary", text: "Show the numbers", match: :first).click
    expect(page).to have_content("250")
  end
end
