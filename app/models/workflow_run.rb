# One person going through one version of a workflow.
class WorkflowRun < ApplicationRecord
  IN_FLIGHT = %w[ active waiting ].freeze

  belongs_to :workflow
  belongs_to :workflow_version
  belongs_to :person
  belongs_to :trigger_subject, polymorphic: true, optional: true
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  has_many :step_executions, class_name: "WorkflowStepExecution", dependent: :destroy

  enum :status, { active: "active", waiting: "waiting", completed: "completed", exited: "exited", cancelled: "cancelled", failed: "failed" },
    default: :active, validate: true

  scope :in_flight, -> { where(status: IN_FLIGHT) }
  scope :recent_first, -> { order(started_at: :desc, id: :desc) }

  def in_flight? = status.in?(IN_FLIGHT)
  def definition = workflow_version.parsed_definition
  def current_step = current_step_id && definition.find(current_step_id)

  def cancel!(reason)
    with_lock { update!(status: :cancelled, exit_reason: reason, finished_at: Time.current, wake_at: nil) if in_flight? }
  end

  # After a failure: try the failed step again.
  def retry!
    with_lock do
      return unless failed?

      # Back-date the claim so the retried job can pick the step up straight away.
      step_executions.find_by(step_id: current_step_id)&.update!(status: :running, error: nil, updated_at: 1.hour.ago)
      update!(status: :active, exit_reason: nil, finished_at: nil)
    end
    WorkflowStepJob.perform_later(self, current_step_id)
  end
end
