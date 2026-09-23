# Builds a user's DailyBrief. The AI sees only the top insights' kinds, titles, and
# numbers (no private text, notes, or contact details) and returns an order, a reason for
# each, and a short brief. Its choices are checked: it can only reorder the insights it
# was given. Without AI (off, over the limit, unreachable, or a bad answer), the brief
# is the rule-ranked list.
class Insights::Brief
  LIMIT = 15

  SYSTEM = <<~PROMPT.freeze
    You help church staff decide what to do first today. You'll get a numbered list of things that need
    attention. Reply with JSON only, with all three keys, in this order:
    {"brief": "2 to 4 plain sentences on what matters most today and why", "order": [ids, most important first], "reasons": {"id": "one short sentence on why it matters today"}}
    Use only the ids given. Don't invent names, numbers, or facts that aren't in the list.
  PROMPT

  def initialize(user, date: user.church.today)
    @user = user
    @date = date
    @church = user.church
  end

  def build!
    insights = Insights::Ranking.new(@user).insights(limit: LIMIT)
    brief = DailyBrief.find_or_initialize_by(user: @user, date: @date)
    return brief.tap { |b| b.update!(items: [], summary: nil, source: "rules", ai_request: nil) } if insights.empty?

    order, reasons, summary, request = ai_ranking(insights)
    if order
      by_id = insights.index_by(&:id)
      ordered = order.filter_map { |id| by_id[id] }
      ordered += insights - ordered
      brief.update!(items: ordered.map { |insight| { "insight_id" => insight.id, "reason" => reasons[insight.id.to_s].to_s.first(240).presence }.compact },
        summary: summary.to_s.first(1200).presence, source: "ai", ai_request: request)
    else
      brief.update!(items: insights.map { |insight| { "insight_id" => insight.id } }, summary: nil, source: "rules", ai_request: request)
    end
    brief
  end

  private
    def ai_ranking(insights)
      client = Assistant::Client.new(church: @church, user: @user, purpose: "daily_brief")
      return unless client.available?

      lines = insights.map do |insight|
        "#{insight.id}. [#{insight.severity}, #{insight.label}, open #{insight.age_days} days#{", assigned to you" if insight.mine?(@user)}] #{insight.title}" \
          "#{" (#{insight.data.except("queue").map { |k, v| "#{k}: #{v}" }.join(", ")})" if insight.data.except("queue").any?}"
      end
      text, request = client.generate(system: SYSTEM, prompt: "Today is #{I18n.l(@date, format: :long)}.\n\n#{lines.join("\n")}", max_tokens: 700)
      parsed = parse(text) or return [ nil, nil, nil, request ]

      allowed = insights.map(&:id)
      order = Array(parsed["order"]).map { |id| Integer(id, exception: false) }.compact.select { |id| allowed.include?(id) }.uniq
      return [ nil, nil, nil, request ] if order.empty?

      reasons = parsed["reasons"].is_a?(Hash) ? parsed["reasons"].transform_keys(&:to_s).slice(*order.map(&:to_s)) : {}
      [ order, reasons, parsed["brief"].is_a?(String) ? parsed["brief"] : nil, request ]
    rescue Assistant::Client::Unavailable
      nil
    end

    def parse(text)
      json = text.to_s[/\{.*\}/m] or return
      JSON.parse(json)
    rescue JSON::ParserError
      nil
    end
end
