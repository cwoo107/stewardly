# Answers a report question by letting the AI call read-only metric tools (at most
# MAX_ROUNDS rounds), then checks that every figure in its answer came from the data.
# The model never sees raw records or SQL, only tool descriptions and tool results.
class Reports::Assistant
  MAX_ROUNDS = 5

  SYSTEM = <<~PROMPT.freeze
    You answer questions from church staff about their church's data. You can only know numbers by calling the
    tools provided; never estimate, guess, or use outside knowledge for figures. Call the tools you need, then
    answer in plain language in 2 to 5 sentences, quoting the numbers exactly as the tools returned them. If the
    tools can't answer the question, say so and suggest what they could look at instead. Today is %<today>s.
  PROMPT

  def initialize(message)
    @message = message
    @conversation = message.report_conversation
    @user = @conversation.user
    @church = @conversation.church
  end

  def answer!
    client = Assistant::Client.new(church: @church, user: @user, purpose: "report_assistant")
    tools = Reports::Tools.available(@user, @church)
    messages = [ { role: "system", content: format(SYSTEM, today: I18n.l(@church.today, format: :long)) } ] + history
    calls = []
    request = nil
    final = nil

    MAX_ROUNDS.times do
      reply, request = client.chat(messages:, tools: tools.map(&:definition), max_tokens: 900)
      if reply.tool_calls.empty?
        final = reply.text
        break
      end

      # TODO(verify vendor docs): the assistant turn is echoed back as Ollama returned it, and tool results are
      # sent as { role: "tool", content:, tool_name: }.
      messages << (reply.raw["message"] || { role: "assistant", content: reply.text })
      reply.tool_calls.each do |tool_call|
        call = Reports::Execution.run(tool_call.name, tool_call.arguments, user: @user, church: @church)
        calls << call
        messages << { role: "tool", tool_name: tool_call.name, content: (call["result"] || { "error" => call["error"] }).to_json }
      end
    end

    return fail!("The assistant didn't reach an answer. Try asking a narrower question.", calls, request) if final.blank?

    unverified = Reports::NumberCheck.new(answer: final, tool_calls: calls, question: @message.question).unverified
    @message.update!(content: final, tool_calls: calls, unverified_figures: unverified, status: :done, ai_request: request, error: nil)
  rescue Assistant::Client::Unavailable => error
    fail!("#{error.message}. You can still run any metric yourself from the Metrics page.", calls || [], nil)
  end

  private
    # The conversation so far (text only), most recent 10 turns.
    def history
      @conversation.messages.where.not(id: @message.id).done.last(10).map { |turn| { role: turn.role, content: turn.content.to_s } }
    end

    def fail!(reason, calls, request)
      @message.update!(status: :failed, error: reason, tool_calls: calls, ai_request: request)
    end
end
