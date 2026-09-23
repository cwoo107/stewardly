# The one way the app talks to AI. The model runs on the platform's own Ollama server
# (OLLAMA_URL), so church data never goes to a third party; the model is ENV["AI_MODEL"].
#
# Every call checks the church's AI switch and monthly token cap and is logged as an
# AiRequest. Callers get text back, or Assistant::Unavailable with a reason to show staff.
class Assistant::Client
  class Unavailable < StandardError; end

  def self.provider = Assistant::Providers::Ollama.new

  def initialize(church:, purpose:, user: nil, provider: self.class.provider)
    @church = church
    @purpose = purpose
    @user = user
    @provider = provider
  end

  # One prompt, one text answer: [text, AiRequest].
  def generate(system:, prompt:, max_tokens: 800)
    reply, request = chat(messages: [ { role: "system", content: system }, { role: "user", content: prompt } ], max_tokens:)
    raise Unavailable, "The AI answered with nothing" if reply.text.blank?

    [ reply.text, request ]
  end

  # A conversation, optionally with tools the model may call: [Reply, AiRequest].
  def chat(messages:, tools: nil, max_tokens: 800)
    check_available!
    request = AiRequest.create!(user: @user, purpose: @purpose, provider: @provider.name, model:, prompt: { messages:, tools: tools&.map { |t| t.dig(:function, :name) }, max_tokens: }.compact)
    reply = @provider.chat(model:, messages:, max_tokens:, tools:)
    request.update!(status: :succeeded, response: reply.raw, input_tokens: reply.input_tokens, output_tokens: reply.output_tokens,
      tool_calls: reply.tool_calls.map { |call| { "name" => call.name, "arguments" => call.arguments } })
    [ reply, request ]
  rescue Assistant::Providers::Error => error
    request&.update!(status: :failed, error: error.message.first(1000))
    raise Unavailable, "The AI server didn't answer (#{error.message.truncate(120)})"
  end

  def available?
    check_available!
    true
  rescue Unavailable
    false
  end

  private
    def model = ENV["AI_MODEL"]

    def check_available!
      raise Unavailable, "AI is turned off for #{@church.name}" unless @church.ai_enabled?
      raise Unavailable, "AI_MODEL isn't set on the server" if model.blank?
      raise Unavailable, "This month's AI limit is used up" if AiRequest.tokens_used_since(@church.now.beginning_of_month) >= @church.ai_monthly_token_cap
    end
end
