require "rails_helper"

RSpec.describe Assistant::Providers::Ollama do
  let(:provider) { described_class.new(url: "http://ollama.internal:11434", api_key: "secret") }

  it "posts a non-streaming chat and reads the reply and token counts" do
    stub = stub_request(:post, "http://ollama.internal:11434/api/chat")
      .with(headers: { "Authorization" => "Bearer secret" }, body: hash_including("model" => "llama3.1", "stream" => false, "options" => { "num_predict" => 100 }))
      .to_return(status: 200, body: { message: { role: "assistant", content: " Hi Ana! " }, prompt_eval_count: 12, eval_count: 5, done: true }.to_json)

    reply = provider.chat(model: "llama3.1", messages: [ { role: "user", content: "hi" } ], max_tokens: 100)
    expect(stub).to have_been_requested
    expect(reply.to_h.slice(:text, :input_tokens, :output_tokens)).to eq(text: "Hi Ana!", input_tokens: 12, output_tokens: 5)
  end

  it "turns HTTP and connection errors into Provider errors" do
    stub_request(:post, "http://ollama.internal:11434/api/chat").to_return(status: 404, body: "model not found")
    expect { provider.chat(model: "x", messages: [], max_tokens: 1) }.to raise_error(Assistant::Providers::Error, /404/)
    stub_request(:post, "http://ollama.internal:11434/api/chat").to_raise(Errno::ECONNREFUSED)
    expect { provider.chat(model: "x", messages: [], max_tokens: 1) }.to raise_error(Assistant::Providers::Error, /ECONNREFUSED/)
  end

  it "sends tools and reads tool calls from the reply" do
    stub_request(:post, "http://ollama.internal:11434/api/chat")
      .with { |request| JSON.parse(request.body)["tools"].first["type"] == "function" }
      .to_return(status: 200, body: { message: { role: "assistant", content: "", tool_calls: [ { function: { name: "people_counts", arguments: { by: "age_band" } } } ] } }.to_json)
    reply = provider.chat(model: "llama3.1", messages: [], max_tokens: 10, tools: [ Reports::Tools::PeopleCounts.definition ])
    expect(reply.tool_calls).to eq([ Assistant::Providers::ToolCall.new(name: "people_counts", arguments: { "by" => "age_band" }) ])
  end

  # Real responses captured from Ollama 0.30.3 with gpt-oss:20b.
  it "reads a real chat response (reasoning models also return message.thinking)" do
    stub_request(:post, "http://ollama.internal:11434/api/chat").to_return(status: 200, body: file_fixture("ollama/chat.json").read)
    reply = provider.chat(model: "gpt-oss:20b", messages: [], max_tokens: 200)
    expect(reply.to_h.slice(:text, :input_tokens, :output_tokens)).to eq(text: "Hello Ana!", input_tokens: 86, output_tokens: 101)
  end

  it "reads a real tool call, and a real answer after the tool result" do
    stub_request(:post, "http://ollama.internal:11434/api/chat").to_return({ body: file_fixture("ollama/tool_call.json").read }, { body: file_fixture("ollama/tool_answer.json").read })
    first = provider.chat(model: "gpt-oss:20b", messages: [], max_tokens: 600, tools: [ Reports::Tools::PeopleCounts.definition ])
    expect(first.tool_calls).to eq([ Assistant::Providers::ToolCall.new(name: "people_counts", arguments: { "by" => "membership status" }) ])
    expect(first.raw["message"]).to include("role" => "assistant", "tool_calls" => be_present) # echoed back as-is
    second = provider.chat(model: "gpt-oss:20b", messages: [], max_tokens: 600)
    expect(second.text).to include("Member", "62", "126")
  end

  it "sends the thinking level, and explains when reasoning used up every token" do
    thinking = described_class.new(url: "http://ollama.internal:11434", think: "low")
    stub = stub_request(:post, "http://ollama.internal:11434/api/chat").with(body: hash_including("think" => "low"))
      .to_return(body: { message: { role: "assistant", content: "", thinking: "hmm" }, done_reason: "length" }.to_json)
    expect { thinking.chat(model: "gpt-oss:20b", messages: [], max_tokens: 5) }.to raise_error(Assistant::Providers::Error, /ran out of room/)
    expect(stub).to have_been_requested
  end
end
