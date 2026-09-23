# Starts a run for a person, if the workflow is live, they meet the entry conditions,
# and they aren't already in it (unless re-entry is allowed).
class Workflow::Enrollment
  def initialize(workflow, person, subject: nil)
    @workflow = workflow
    @person = person
    @subject = subject
  end

  # The new WorkflowRun, or nil when the person doesn't enter.
  def start!(once_per_day: false)
    version = @workflow.current_version
    return unless @workflow.active? && version && !@person.merged?
    return if in_flight? && !@workflow.allow_reentry?
    return if once_per_day && @workflow.runs.where(person: @person, started_at: @person.church.now.beginning_of_day..).exists?
    return unless meets_entry_conditions?(version.parsed_definition)

    run = @workflow.runs.create!(workflow_version: version, person: @person, trigger_subject: @subject, started_at: Time.current,
      current_step_id: version.parsed_definition.first_step_id, allow_concurrent: @workflow.allow_reentry?)
    run.current_step_id ? WorkflowStepJob.perform_later(run, run.current_step_id) : run.update!(status: :completed, finished_at: Time.current)
    run
  rescue ActiveRecord::RecordNotUnique
    nil # a run started at the same moment
  end

  private
    def in_flight? = @workflow.runs.in_flight.where(person: @person).exists?

    def meets_entry_conditions?(definition)
      return true unless definition.entry_conditions?

      definition.entry.people.where(id: @person.id).exists?
    end
end
