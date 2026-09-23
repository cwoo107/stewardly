# A published copy of a workflow's definition. Never edited: publishing again makes a new one.
class WorkflowVersion < ApplicationRecord
  belongs_to :workflow, inverse_of: :versions
  belongs_to :published_by, class_name: "User", optional: true
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  has_many :runs, class_name: "WorkflowRun", dependent: :restrict_with_error

  def parsed_definition = @parsed_definition ||= Workflow::Definition.new(definition)
end
