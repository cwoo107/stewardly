require "rails_helper"

RSpec.describe Assistant::Client do
  let(:provider) { instance_double(Assistant::Providers::Ollama, name: "ollama") }
  let(:client) { described_class.new(church:, purpose: "test", provider:) }
  let(:reply) { Assistant::Providers::Reply.new(text: "Hello!", input_tokens: 40, output_tokens: 10, raw: { "message" => { "content" => "Hello!" } }) }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("AI_MODEL").and_return("llama3.1:8b")
    church.update!(ai_enabled: true)
  end

  it "logs every request and response" do
    allow(provider).to receive(:chat).and_return(reply)
    text, request = client.generate(system: "Be kind", prompt: "Say hi")
    expect(text).to eq("Hello!")
    expect(request.reload).to have_attributes(status: "succeeded", model: "llama3.1:8b", provider: "ollama", input_tokens: 40, output_tokens: 10)
    expect(request.prompt["messages"].last).to eq("role" => "user", "content" => "Say hi")
    expect(provider).to have_received(:chat).with(model: "llama3.1:8b", messages: array_including(hash_including(role: "system")), max_tokens: 800, tools: nil)
  end

  it "refuses when AI is off or the monthly cap is used up" do
    church.update!(ai_enabled: false)
    expect { client.generate(system: "", prompt: "") }.to raise_error(described_class::Unavailable, /turned off/)

    church.update!(ai_enabled: true, ai_monthly_token_cap: 100)
    create(:ai_request, input_tokens: 90, output_tokens: 20)
    expect { client.generate(system: "", prompt: "") }.to raise_error(described_class::Unavailable, /limit/)
  end

  it "logs failures and says the server didn't answer" do
    allow(provider).to receive(:chat).and_raise(Assistant::Providers::Error, "Connection refused")
    expect { client.generate(system: "", prompt: "") }.to raise_error(described_class::Unavailable, /didn't answer/)
    expect(AiRequest.last).to have_attributes(status: "failed", error: "Connection refused")
  end
end
