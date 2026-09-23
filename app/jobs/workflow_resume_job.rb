# After a workflow is unpaused: pick up runs that stopped while it was paused.
class WorkflowResumeJob < ApplicationJob
  queue_as :default

  def perform(workflow)
    workflow.runs.in_flight.where("wake_at IS NULL OR wake_at <= ?", Time.current).find_each do |run|
      run.update!(status: :active) if run.waiting? && run.wake_at.nil?
      WorkflowStepJob.perform_later(run, run.current_step_id) if run.current_step_id
    end
  end
end
