# Writes a MessageDraft for an AI draft step. The AI sees only what it needs to write a
# friendly note: the person's first name, membership status, pathway stage, group and
# serving counts, and the kinds (not contents) of recent non-sensitive touchpoints.
# Never prayer, benevolence, contact details, or notes.
class Workflow::Drafting
  SYSTEM = <<~PROMPT.freeze
    You write short, warm emails on behalf of a church's staff. Write only the body of the email in
    plain text or simple Markdown: no subject line, no placeholders, no sign-off name (the church adds
    its own footer). Don't invent events, dates, names, or facts that aren't given to you. Keep it under
    150 words unless the instructions say otherwise. The details about the person are background for
    you only: never mention their membership status, pathway stage, group or team counts, or contact
    history to them, and never use internal labels like "Connect", "Grow", or "Serve".
  PROMPT

  def initialize(run, execution, config)
    @run = run
    @execution = execution
    @config = config
    @person = run.person
  end

  def draft!
    body, request, note = generate
    MessageDraft.create!(workflow_step_execution: @execution, person: @person, subject:,
      email_template_id: @config["email_template_id"].presence, email_topic_id: @config["email_topic_id"],
      body:, ai_request: request, source: body ? "ai" : "staff", note:)
  rescue ActiveRecord::RecordNotUnique
    @execution.reload.message_draft
  end

  def context
    stage = @person.pathway_placement&.pathway_stage&.name
    touchpoints = @person.touchpoints.where(sensitive: false).where.not(kind: %w[ prayer_follow_up ]).order(occurred_at: :desc).limit(5)
    {
      "church" => church.name, "first_name" => @person.nickname.presence || @person.first_name,
      "membership_status" => @person.membership_status.humanize, "pathway_stage" => stage,
      "groups" => @person.group_memberships.count, "serving_teams" => @person.team_memberships.count,
      "recent_contact" => touchpoints.map { |touchpoint| "#{touchpoint.kind.humanize} on #{touchpoint.occurred_at.to_date}" }
    }.compact
  end

  private
    def church = @run.church

    # Personalised now, so reviewers see exactly what will go out.
    def subject
      Email::Liquid.render(@config["subject"].to_s, "person" => Email::Drops::Person.new(@person), "church" => Email::Drops::Church.new(church))
    rescue Liquid::Error
      @config["subject"]
    end

    def generate
      prompt = "Staff instructions:\n#{@config["instructions"]}\n\nAbout the person:\n#{JSON.pretty_generate(context)}"
      text, request = Assistant::Client.new(church:, purpose: "workflow_draft").generate(system: SYSTEM, prompt:)
      [ text, request, nil ]
    rescue Assistant::Client::Unavailable => error
      [ nil, nil, "#{error.message}. Write this message yourself: #{@config["instructions"]}".first(255) ]
    end
end
