require "rails_helper"

RSpec.describe "Task board", :js do
  it "moves a task to another column by dragging" do
    create(:task, title: "Call the new family", status: "todo")
    create(:task, title: "Already underway", status: "in_progress")
    sign_in_as(create(:user, :staff))

    visit tasks_path
    card = find("#tasks_todo li", text: "Call the new family")
    card.drag_to(find("#tasks_in_progress li", text: "Already underway"))

    expect(page).to have_css("#tasks_in_progress", text: "Call the new family")
    expect { Task.find_by!(title: "Call the new family").reload.status }.to eventually_eq("in_progress")
  end
end
