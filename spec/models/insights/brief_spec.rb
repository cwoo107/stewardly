require "rails_helper"

RSpec.describe Insights::Brief do
  let(:user) { create(:user, :church_admin) }
  let!(:low) { create(:insight, severity: "low", title: "Low thing") }
  let!(:high) { create(:insight, severity: "high", title: "High thing") }
  let!(:mine) { create(:insight, severity: "medium", title: "My thing", audience_user_ids: [ user.id ]) }

  it "ranks by rules when AI is off" do
    brief = described_class.new(user).build!
    expect(brief).to be_source_rules
    expect(brief.insights.map(&:title)).to eq([ "High thing", "My thing", "Low thing" ])
  end

  it "uses the AI's order and reasons, ignoring ids it wasn't given" do
    church.update!(ai_enabled: true)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("AI_MODEL").and_return("llama3.1")
    json = { order: [ low.id, 999_999, high.id ], reasons: { low.id.to_s => "Quick win today" }, brief: "Start with the quick win." }.to_json
    allow_any_instance_of(Assistant::Providers::Ollama).to receive(:chat)
      .and_return(Assistant::Providers::Reply.new(text: "Here you go: #{json}", input_tokens: 5, output_tokens: 5, raw: {}))

    brief = described_class.new(user.reload).build!
    expect(brief).to be_source_ai
    expect(brief.insights.map(&:title)).to eq([ "Low thing", "High thing", "My thing" ])
    expect(brief.reason_for(low)).to eq("Quick win today")
    expect(brief.summary).to eq("Start with the quick win.")
    expect(brief.ai_request.prompt.to_json).to include("High thing")
  end

  it "falls back to rules when the AI's answer isn't usable" do
    church.update!(ai_enabled: true)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("AI_MODEL").and_return("llama3.1")
    allow_any_instance_of(Assistant::Providers::Ollama).to receive(:chat)
      .and_return(Assistant::Providers::Reply.new(text: "Sorry, I can't", input_tokens: 1, output_tokens: 1, raw: {}))
    expect(described_class.new(user.reload).build!).to be_source_rules
  end
end
