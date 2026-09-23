# Starts runs for an event (Workflow::Events.publish).
class WorkflowTriggerJob < ApplicationJob
  queue_as :default

  def perform(type, person, subject = nil)
    Workflow::Events.dispatch(type, person:, subject:)
  end
end
