# The step types a workflow can use. Each class describes its settings (defaults,
# validation, summary) and performs itself for one run.
module Workflow::Steps
  # What a step did. status: :done (move on), :wait (come back at wake_at), :skip (move on,
  # noting why), or :exit (end the run). branch picks a condition's yes/no list.
  Outcome = Data.define(:status, :branch, :wake_at, :result) do
    def self.done(result = {}) = new(:done, nil, nil, result)
    def self.skip(reason) = new(:skip, nil, nil, { "reason" => reason })
    def self.wait(until_time, result = {}) = new(:wait, nil, until_time, result)
    def self.branch(name, result = {}) = new(:done, name, nil, result)
  end

  def self.types
    {
      "send_email" => SendEmail, "wait" => Wait, "condition" => Condition, "add_tag" => AddTag, "remove_tag" => RemoveTag,
      "add_to_group" => AddToGroup, "create_task" => CreateTask, "notify_staff" => NotifyStaff,
      "update_pathway" => UpdatePathway, "enroll_in_campaign" => EnrollInCampaign, "ai_draft" => AiDraft
    }
  end

  def self.for(step) = types.fetch(step["type"]) { Unknown }.new(step)
  def self.label(type) = types.fetch(type) { Unknown }.label

  def self.build(type)
    klass = types.fetch(type) { raise ArgumentError, "Unknown step type: #{type}" }
    step = { "id" => SecureRandom.alphanumeric(8), "type" => type, "config" => klass.default_config.deep_dup }
    step.merge!("yes" => [], "no" => []) if type == "condition"
    step
  end
end
