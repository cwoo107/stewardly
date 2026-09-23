# Emails staff about this person (an in-app inbox can come later).
class Workflow::Steps::NotifyStaff < Workflow::Steps::Base
  self.label = "Notify staff"
  self.default_config = { "user_ids" => [], "message" => "{{ person.name }} needs attention." }

  def users = User.where(id: Array(config["user_ids"]).compact_blank)

  def errors
    problems = []
    problems << "choose who to notify" if users.none?
    problems << "add a message" if config["message"].blank?
    problems
  end

  def summary = "Notify #{users.map(&:name).to_sentence.presence || "…"}"

  def perform(run, execution)
    return Outcome.done(execution.result) if execution.result["notified"]

    message = liquid(config["message"], run.person)
    users.each { |user| WorkflowMailer.with(user:, run:, message:).staff_notification.deliver_later }
    Outcome.done("notified" => users.map(&:id))
  end
end
