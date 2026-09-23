class Workflow::Steps::CreateTask < Workflow::Steps::Base
  self.label = "Create a task"
  self.default_config = { "title" => "Follow up with {{ person.name }}", "due_in_days" => 2, "priority" => "normal" }

  def errors
    problems = []
    problems << "add a title" if config["title"].blank?
    problems << "choose who it's for" unless exists?(User, "owner_id")
    problems << "has Liquid that doesn't parse" unless (Email::Liquid.parse(config["title"]) rescue nil)
    problems
  end

  def summary
    owner = User.find_by(id: config["owner_id"])&.name
    "Task#{" for #{owner}" if owner}: #{config["title"]}"
  end

  def perform(run, execution)
    task = Task.find_by(workflow_step_execution: execution) || Task.create!(
      workflow_step_execution: execution, title: liquid(config["title"], run.person).squish.first(200),
      notes: [ liquid(config["notes"], run.person).presence, "From the “#{run.workflow.name}” workflow for #{run.person.name}." ].compact.join("\n\n"),
      owner_id: config["owner_id"], priority: Task.priorities.key?(config["priority"]) ? config["priority"] : "normal",
      due_on: config["due_in_days"].presence && church.today + config["due_in_days"].to_i)
    Outcome.done("task_id" => task.id)
  end
end
