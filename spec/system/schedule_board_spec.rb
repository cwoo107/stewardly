require "rails_helper"

RSpec.describe "Scheduling volunteers", :js do
  let(:team) { create(:team, name: "Greeters") }
  let(:position) { create(:position, team:, name: "Door") }
  let(:service) { create(:worship_service, name: "Sunday 9am") }

  before do
    create(:position_need, needable: service, position:, quantity: 2)
    %w[ Ann Ben ].each { |name| create(:team_membership, team:, person: create(:person, first_name: name, last_name: "Greeter")) }
    sign_in_as(create(:user, :staff))
  end

  it "drags a team member into an open spot" do
    visit team_schedule_path(team)
    slot = first("[data-schedule-board-target=slot]")
    find("[data-schedule-board-target=roster] li", text: "Ann Greeter").drag_to(slot)

    expect(page).to have_css("[data-schedule-board-target=slot] li", text: "Ann Greeter")
    expect { Assignment.joins(:person).where(people: { first_name: "Ann" }).count }.to eventually_eq(1)
  end

  it "auto-fills and sends requests" do
    visit team_schedule_path(team)
    click_on "Auto-fill open spots"
    expect(page).to have_content("Suggested")
    accept_confirm { click_on "Send", exact: false }
    expect(page).to have_content("Sent")
    expect(Assignment.awaiting_request).to be_empty
  end
end
