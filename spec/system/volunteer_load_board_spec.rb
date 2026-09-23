require "rails_helper"

RSpec.describe "Volunteer load on the schedule board", :js do
  it "badges people at risk and warns when scheduling pushes someone over" do
    church.update!(volunteer_load_thresholds: { "at_risk_consecutive_weeks" => 1 })
    team = create(:team, name: "Greeters")
    position = create(:position, team:, name: "Door")
    service = create(:worship_service, name: "Sunday 9am")
    create(:position_need, needable: service, position:, quantity: 1)
    create(:team_membership, team:, person: create(:person, first_name: "Ann", last_name: "Greeter"), created_at: 1.year.ago)
    page.driver.resize(1400, 1000)
    sign_in_as(create(:user, :staff))

    visit team_schedule_path(team)
    find("[data-schedule-board-target=roster] li", text: "Ann Greeter").drag_to(first("[data-schedule-board-target=slot]"))

    expect(page).to have_content("Ann Greeter is now at risk of burnout")
    expect(page).to have_css("[data-schedule-board-target=slot] li", text: "At risk")
  end
end
