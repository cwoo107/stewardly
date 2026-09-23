# One step of one run. Unique on (run, step), so a retried job finds the execution it
# already started instead of repeating the step.
class WorkflowStepExecution < ApplicationRecord
  belongs_to :workflow_run
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  has_one :delivery, dependent: :nullify
  has_one :message_draft, dependent: :delete
  has_one :task, dependent: :nullify

  enum :status, { running: "running", waiting: "waiting", completed: "completed", skipped: "skipped", failed: "failed" },
    default: :running, validate: true

  def finished? = completed? || skipped?
end
