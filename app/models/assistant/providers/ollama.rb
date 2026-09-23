# A self-hosted Ollama server's chat API.
#
# Verified against Ollama 0.30.3 with gpt-oss:20b (responses captured in
# spec/fixtures/files/ollama): request { model, messages, stream: false, tools, think,
# options: { num_predict } }; response { message: { content, thinking, tool_calls: [{ id,
# function: { index, name, arguments } }] }, done_reason, prompt_eval_count, eval_count };
# tool results go back as { role: "tool", tool_name:, content: }. Tool calling needs a model
# that supports it (gpt-oss, Llama 3.1, Qwen 2.5). Re-check when upgrading Ollama.
#
# AI_THINK ("low", "medium", "high", "true", "false"): how much a reasoning model thinks before
# answering. Reasoning tokens count against num_predict. Leave it unset for models that don't
# reason: Ollama refuses `think` for them.
class Assistant::Providers::Ollama
  def initialize(url: ENV.fetch("OLLAMA_URL", "http://localhost:11434"), api_key: ENV["OLLAMA_API_KEY"], timeout: 120, think: ENV["AI_THINK"])
    @uri = URI.join(url.end_with?("/") ? url : "#{url}/", "api/chat")
    @api_key = api_key
    @timeout = timeout
    @think = { "true" => true, "false" => false }.fetch(think.to_s, think.presence)
  end

  def name = "ollama"

  # tools: [{ type: "function", function: { name:, description:, parameters: JSON schema } }]
  def chat(model:, messages:, max_tokens:, tools: nil)
    request = Net::HTTP::Post.new(@uri, "Content-Type" => "application/json")
    request["Authorization"] = "Bearer #{@api_key}" if @api_key.present? # when the server sits behind an authenticating proxy
    request.body = { model:, messages:, stream: false, tools: tools.presence, think: @think, options: { num_predict: max_tokens } }.compact.to_json

    response = Net::HTTP.start(@uri.host, @uri.port, use_ssl: @uri.scheme == "https", open_timeout: 5, read_timeout: @timeout) { |http| http.request(request) }
    raise Assistant::Providers::Error, "HTTP #{response.code}: #{response.body.to_s.truncate(200)}" unless response.is_a?(Net::HTTPSuccess)

    body = JSON.parse(response.body)
    text = body.dig("message", "content").to_s.strip
    tool_calls = Array(body.dig("message", "tool_calls")).map do |call|
      arguments = call.dig("function", "arguments")
      arguments = JSON.parse(arguments) if arguments.is_a?(String)
      Assistant::Providers::ToolCall.new(name: call.dig("function", "name").to_s, arguments: arguments.to_h)
    end
    if text.empty? && tool_calls.empty?
      raise Assistant::Providers::Error, body["done_reason"] == "length" ? "The model ran out of room before answering (try a lower AI_THINK)" : "Empty reply"
    end

    Assistant::Providers::Reply.new(text:, input_tokens: body["prompt_eval_count"].to_i, output_tokens: body["eval_count"].to_i, raw: body, tool_calls:)
  rescue JSON::ParserError, SocketError, IOError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout => error
    raise Assistant::Providers::Error, "#{error.class}: #{error.message}"
  end
end
