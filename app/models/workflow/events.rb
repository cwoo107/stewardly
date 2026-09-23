# Where model callbacks announce things workflows can trigger on. Only enqueues a job
# when some active workflow listens for that event.
module Workflow::Events
  def self.publish(type, person:, subject: nil)
    return unless person && Workflow::Trigger::TYPES.key?(type)

    # Callbacks fire after commit, possibly outside the tenant block that made the record.
    ActsAsTenant.with_tenant(person.church) do
      WorkflowTriggerJob.perform_later(type, person, subject) if Workflow.listening_for(type).exists?
    end
  end

  # Starts runs in every active workflow this event matches.
  def self.dispatch(type, person:, subject: nil)
    Workflow.listening_for(type).includes(:current_version).find_each do |workflow|
      next unless workflow.published_definition.trigger.matches?(subject)

      Workflow::Enrollment.new(workflow, person, subject:).start!
    end
  end
end
