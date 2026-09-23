# Runs one step of a run (from WorkflowStepJob) and moves the run along, in three parts:
#
#   1. claim   (run locked): the job must be for the run's current step; its
#              WorkflowStepExecution (unique on run and step) is created or reclaimed.
#   2. perform (no lock or transaction): the step's work. Sends happen here, so a later
#              rollback can never undo the record of an email that already went out.
#   3. apply   (run locked): record the outcome and choose the next step.
#
# A retried job finds the finished execution and only advances. Steps are written to be
# safe to repeat: deliveries, tasks, and drafts are unique per execution.
class Workflow::Execution
  STALE_CLAIM = 10.minutes

  def initialize(run)
    @run = run
  end

  def perform(step_id)
    execution, step = claim(step_id)
    return unless execution

    outcome = execution.finished? ? Workflow::Steps::Outcome.branch(execution.result["branch"]) : Workflow::Steps.for(step).perform(@run, execution)
    next_job = @run.with_lock { apply(outcome, step_id, execution) if @run.in_flight? && @run.current_step_id == step_id }
    next_job&.call
  rescue StandardError => error
    fail!(step_id, error)
  end

  private
    def claim(step_id)
      @run.with_lock do
        next unless @run.in_flight? && @run.current_step_id == step_id
        next @run.update!(status: :waiting) && nil if @run.workflow.paused?
        next if @run.wake_at&.future?

        step = @run.definition.find(step_id)
        next exit_run!("The step was removed") && nil unless step

        execution = @run.step_executions.find_or_create_by!(step_id:) { |e| e.step_type = step["type"] }
        next if execution.running? && !execution.previously_new_record? && execution.updated_at > STALE_CLAIM.ago # another job has it

        execution.update!(status: :running) if execution.waiting?
        execution.touch unless execution.finished?
        [ execution, step ]
      end
    end

    # Records the outcome and returns what to enqueue once the lock is released.
    def apply(outcome, step_id, execution)
      if outcome.status == :wait
        execution.update!(status: :waiting, result: execution.result.merge(outcome.result))
        @run.update!(status: :waiting, wake_at: outcome.wake_at)
        return -> { WorkflowStepJob.set(wait_until: outcome.wake_at).perform_later(@run, step_id) }
      end

      unless execution.finished?
        execution.update!(status: outcome.status == :skip ? :skipped : :completed, executed_at: Time.current,
          result: execution.result.merge(outcome.result).merge("branch" => outcome.branch).compact)
      end

      next_id = @run.definition.next_step_id(step_id, branch: outcome.branch)
      return finish! unless next_id

      @run.update!(status: :active, current_step_id: next_id, wake_at: nil)
      -> { WorkflowStepJob.perform_later(@run, next_id) }
    end

    def finish!
      @run.update!(status: :completed, current_step_id: nil, wake_at: nil, finished_at: Time.current)
      nil
    end

    def exit_run!(reason)
      @run.update!(status: :exited, exit_reason: reason, finished_at: Time.current)
    end

    def fail!(step_id, error)
      Rails.logger.error("[workflows] run #{@run.id} step #{step_id} failed: #{error.class}: #{error.message}")
      @run.reload.with_lock do
        execution = @run.step_executions.find_or_create_by!(step_id:) { |e| e.step_type = @run.definition.find(step_id)&.dig("type") || "unknown" }
        execution.update!(status: :failed, error: "#{error.class}: #{error.message}".first(1000))
        @run.update!(status: :failed, exit_reason: error.message.first(255), finished_at: Time.current)
      end
    end
end
