# An automation: a trigger, optional entry conditions, and ordered steps. Staff edit
# draft_definition; publishing freezes it into a new WorkflowVersion, and runs always
# finish on the version they started with.
class Workflow < ApplicationRecord
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :current_version, class_name: "WorkflowVersion", optional: true
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  # Runs go first: versions can't be deleted while runs point at them.
  before_destroy { update_column(:current_version_id, nil) if current_version_id }
  has_many :runs, class_name: "WorkflowRun", dependent: :destroy
  has_many :versions, -> { order(number: :desc) }, class_name: "WorkflowVersion", dependent: :destroy, inverse_of: :workflow

  enum :status, { draft: "draft", active: "active", paused: "paused" }, default: :draft, validate: true

  validates :name, presence: true

  scope :alphabetical, -> { order(:name) }
  scope :listening_for, ->(trigger_type) { active.where(trigger_type:) }

  def draft = Workflow::Definition.new(draft_definition)
  def published_definition = current_version&.parsed_definition

  # The draft differs from what's published (or nothing is published yet).
  def unpublished_changes? = current_version.nil? || current_version.definition != draft_definition

  def publish!(by: Current.user)
    errors = draft.errors
    raise ArgumentError, errors.to_sentence if errors.any?

    transaction do
      lock!
      version = versions.create!(number: (versions.maximum(:number) || 0) + 1, definition: draft_definition, published_by: by, published_at: Time.current)
      update!(current_version: version, trigger_type: draft.trigger.type, status: paused? ? :paused : :active)
      version
    end
  end

  def pause! = update!(status: :paused)

  def resume!
    update!(status: :active)
    WorkflowResumeJob.perform_later(self)
  end

  # The kill switch: every in-flight run stops where it is.
  def stop_all_runs!
    runs.in_flight.find_each { |run| run.cancel!("Stopped by #{Current.user&.name || "staff"}") }
  end

  # Editing the draft (the builder). Steps live in lists: the top level (parent nil) or a
  # condition step's "yes"/"no" branch.
  def add_step!(type, parent_id: nil, branch: nil)
    step = Workflow::Steps.build(type)
    update_draft! { |definition| definition.insert(step, parent_id:, branch:) }
    step
  end

  def update_step!(id, config) = update_draft! { |definition| definition.update_config(id, config) }
  def remove_step!(id) = update_draft! { |definition| definition.remove(id) }
  def move_step!(id, index) = update_draft! { |definition| definition.move(id, index) }

  def update_trigger!(trigger, entry)
    update_draft! do |definition|
      definition.trigger = trigger
      definition.entry = entry
    end
  end

  private
    def update_draft!
      definition = draft
      yield definition
      update!(draft_definition: definition.to_h)
    end
end
