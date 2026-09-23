# One move on the pathway (the first placement, forward, or back). Workflows trigger
# on these ("pathway stage changes").
class PathwayTransition < ApplicationRecord
  belongs_to :person
  belongs_to :from_stage, class_name: "PathwayStage", optional: true
  belongs_to :to_stage, class_name: "PathwayStage"
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  enum :direction, { placed: "placed", forward: "forward", back: "back" }, validate: true

  after_create_commit do
    ActiveSupport::Notifications.instrument("pathway.stage_changed", transition: self)
    Workflow::Events.publish("pathway_stage_changed", person:, subject: self)
  end

  scope :recent_first, -> { order(occurred_at: :desc) }
end
