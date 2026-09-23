# Runs one step of a run. Safe to retry: see Workflow::Execution.
class WorkflowStepJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError # the run or person was deleted

  def perform(run, step_id)
    Workflow::Execution.new(run).perform(step_id)
  end
end
