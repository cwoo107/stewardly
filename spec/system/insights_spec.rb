require "rails_helper"

RSpec.describe "Working from today's insights" do
  it "snoozes one and turns another into a task from the dashboard" do
    staff = create(:user, :staff)
    create(:insight, title: "Follow up with Rae", severity: "high", audience_user_ids: [ staff.id ])
    create(:insight, title: "Order new bulletins", severity: "low")
    sign_in_as(staff)

    within(find("li", text: "Follow up with Rae")) do
      find("summary", text: "More").click
      click_on "Make a task"
    end
    expect(page).to have_content("Task created for #{staff.name}")
    expect(Task.last.title).to eq("Follow up with Rae")

    within(find("li", text: "Order new bulletins")) { click_on "Snooze a week" }
    expect(page).to have_content("Snoozed until")
    expect(page).to have_no_content("Order new bulletins")
  end
end

RSpec.describe "Asking the report assistant", :js do
  it "shows the answer and the numbers it's based on" do
    # Answer inline: the polling itself is covered by the request spec.
    allow(ReportAnswerJob).to receive(:perform_later) { |message| ReportAnswerJob.perform_now(message) }
    church.update!(ai_enabled: true)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("AI_MODEL").and_return("llama3.1")
    replies = [
      Assistant::Providers::Reply.new(text: "", input_tokens: 1, output_tokens: 1, raw: { "message" => { "role" => "assistant" } },
        tool_calls: [ Assistant::Providers::ToolCall.new(name: "pathway_funnel", arguments: {}) ]),
      Assistant::Providers::Reply.new(text: "Most people are in Connect.", input_tokens: 1, output_tokens: 1, raw: {})
    ]
    allow_any_instance_of(Assistant::Providers::Ollama).to receive(:chat) { replies.shift }
    sign_in_as(create(:user, :staff))

    visit report_conversations_path
    fill_in "What would you like to know?", with: "Where are people on the pathway?"
    click_button "Ask"
    expect(page).to have_content("Most people are in Connect.")
    expect(page).to have_content("Based on 1 metric")
    expect(page).to have_content("Pathway funnel")
    expect(page).to have_content("People on the pathway")
  end
end
