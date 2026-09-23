require "rails_helper"

RSpec.describe "Insights and reports" do
  include ActiveJob::TestHelper

  let(:user) { create(:user, :staff) }

  before { sign_in_as(user) }

  it "shows today's insights on the dashboard, with actions" do
    insight = create(:insight, title: "Call the Johnsons", audience_user_ids: [ user.id ], action_path: "/people", action_label: "People")
    get root_path
    expect(response.body).to include("Today", "Call the Johnsons", "Yours", "Make a task", "Email me this at 6am")

    patch snooze_insight_path(insight), params: { days: 7 }
    expect(insight.reload).to have_attributes(status: "snoozed", snoozed_until: church.today + 7)
    patch resolve_insight_path(insight)
    expect(insight.reload).to be_resolved
  end

  it "turns an insight into a task, and dismisses others" do
    insight = create(:insight, title: "Plan the picnic", severity: "high")
    post assign_insight_path(insight), params: { owner_id: user.id }
    task = Task.last
    expect(task).to have_attributes(title: "Plan the picnic", owner: user, priority: "high")
    expect(insight.reload).to have_attributes(task:, status: "snoozed")
    task.update!(status: "done")
    expect(insight.reload).to be_resolved

    other = create(:insight)
    patch dismiss_insight_path(other)
    expect(other.reload).to be_dismissed
  end

  it "hides insights for permissions the user doesn't have" do
    create(:insight, title: "Giving backlog", audience_permission: "manage_giving")
    get insights_path
    expect(response.body).not_to include("Giving backlog")
  end

  it "refreshes the brief and turns the 6am email on" do
    post daily_brief_path
    expect(DailyBrief.find_by(user:, date: church.today)).to be_present
    patch daily_brief_path, params: { brief_email: "1" }
    expect(user.reload.brief_email).to be(true)
  end

  it "asks the assistant, polls for the answer, and saves the report" do
    church.update!(ai_enabled: true)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("AI_MODEL").and_return("llama3.1")
    replies = [
      Assistant::Providers::Reply.new(text: "", input_tokens: 1, output_tokens: 1, raw: { "message" => { "role" => "assistant" } },
        tool_calls: [ Assistant::Providers::ToolCall.new(name: "people_counts", arguments: {}) ]),
      Assistant::Providers::Reply.new(text: "Here's the breakdown.", input_tokens: 1, output_tokens: 1, raw: {})
    ]
    allow_any_instance_of(Assistant::Providers::Ollama).to receive(:chat) { replies.shift }

    post report_conversations_path, params: { question: "How many people by status?" }
    conversation = ReportConversation.last
    answer = conversation.messages.role_assistant.last
    get report_conversation_message_path(conversation, answer)
    expect(response.body).to include("Looking at the numbers", "data-controller=\"poll\"")

    perform_enqueued_jobs
    get report_conversation_path(conversation)
    expect(response.body).to include("Here&#39;s the breakdown.", "Based on 1 metric", "People", "Save report")

    post saved_reports_path, params: { message_id: answer.id }
    report = SavedReport.last
    expect(report).to have_attributes(title: "How many people by status?", tool_calls: [ { "name" => "people_counts", "arguments" => {} } ])
    patch saved_report_path(report), params: { saved_report: { pinned: true } }
    get root_path
    expect(response.body).to include("Pinned reports", "How many people by status?")
  end

  it "runs metrics without AI and keeps other people's reports private" do
    get metrics_path
    expect(response.body).to include("Group connection", "Pathway funnel")
    expect(response.body).not_to include("Giving") # staff don't have view_giving
    get metric_path("group_connection", arguments: { miles: 5 })
    expect(response.body).to include("People who joined", "within 5 miles")
    get metric_path("giving_summary")
    expect(response).to have_http_status(:not_found)

    other = create(:saved_report, user: create(:user, :staff))
    get saved_report_path(other)
    expect(response).to have_http_status(:forbidden)
  end
end
