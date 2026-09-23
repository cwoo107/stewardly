# Has the AI draft an email for this person. The draft goes to the approval queue,
# unless a church admin turned on auto-send for this step.
class Workflow::Steps::AiDraft < Workflow::Steps::Base
  self.label = "AI-drafted email"
  self.default_config = { "instructions" => "", "subject" => "", "auto_send" => false }

  def auto_send? = config["auto_send"] == true || config["auto_send"] == "1"

  def errors
    problems = []
    problems << "add instructions for the AI" if config["instructions"].blank?
    problems << "add a subject" if config["subject"].blank?
    problems << "choose a topic" unless exists?(EmailTopic, "email_topic_id")
    problems
  end

  def summary = "AI drafts: #{config["instructions"].to_s.truncate(60)}#{" (sends automatically)" if auto_send?}"

  def perform(run, execution)
    draft = execution.message_draft || Workflow::Drafting.new(run, execution, config).draft!
    return Outcome.done("message_draft_id" => draft.id, "status" => draft.status) unless auto_send? && draft.pending? && draft.source_ai? && draft.body.present?
    return Outcome.wait(Workflow::SendLimit.new(church).next_opening, "deferred" => "Daily send limit reached") if Workflow::SendLimit.new(church).reached?

    draft.approve!(by: nil, auto: true)
    Outcome.done("message_draft_id" => draft.id, "status" => "sent", "auto_sent" => true)
  end
end
