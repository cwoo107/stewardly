require "rails_helper"

RSpec.describe Reports::Assistant do
  let(:user) { create(:user, :church_admin) }
  let(:conversation) { create(:report_conversation, user:) }

  before do
    church.update!(ai_enabled: true)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("AI_MODEL").and_return("llama3.1")
    create_list(:person, 3, membership_status: "member")
  end

  def reply(text: "", tool_calls: []) = Assistant::Providers::Reply.new(text:, input_tokens: 1, output_tokens: 1, raw: { "message" => { "role" => "assistant", "content" => text } }, tool_calls:)

  def ask(question)
    conversation.messages.create!(role: "user", content: question)
    conversation.messages.create!(role: "assistant", status: "pending")
  end

  it "calls tools, answers from their numbers, and flags figures that aren't in the data" do
    members = Person.where(membership_status: "member").count
    replies = [
      reply(tool_calls: [ Assistant::Providers::ToolCall.new(name: "people_counts", arguments: { "by" => "membership_status" }) ]),
      reply(text: "You have #{members} members, up 40% since 2025.")
    ]
    allow_any_instance_of(Assistant::Providers::Ollama).to receive(:chat) { replies.shift }

    message = ask("How many members do we have?")
    described_class.new(message).answer!
    message.reload
    expect(message).to be_done
    expect(message.content).to include("#{members} members")
    expect(message.tool_calls.first).to include("name" => "people_counts", "result" => include("figures"))
    expect(message.unverified_figures).to eq([ "40" ]) # 2025 is a year; the member count came from the tool
    expect(message.ai_request.tool_calls).to eq([])
  end

  it "only runs tools the user may use" do
    staff = create(:user, :staff)
    conversation.update!(user: staff)
    replies = [ reply(tool_calls: [ Assistant::Providers::ToolCall.new(name: "giving_summary", arguments: {}) ]), reply(text: "I can't see giving.") ]
    allow_any_instance_of(Assistant::Providers::Ollama).to receive(:chat) { replies.shift }
    message = ask("How much did we give?")
    described_class.new(message).answer!
    expect(message.reload.tool_calls.first["error"]).to include("No tool called giving_summary")
  end

  it "fails helpfully when AI is off" do
    church.update!(ai_enabled: false)
    message = ask("Anything")
    described_class.new(message).answer!
    expect(message.reload).to have_attributes(status: "failed", error: include("Metrics page"))
  end
end

RSpec.describe Reports::NumberCheck do
  it "accepts rounding, percentages, currency, years, and numbers from the question" do
    calls = [ { "result" => { "figures" => { "Given (dollars)" => 4200.5, "Connected (%)" => 13.1, "People" => 84 } } } ]
    check = described_class.new(answer: "84 people joined in 2026; 13% are connected; $4,200.50 given; within 3 miles; 7 are new.", tool_calls: calls, question: "within 3 miles?")
    expect(check.unverified).to eq([ "7" ])
  end
end
