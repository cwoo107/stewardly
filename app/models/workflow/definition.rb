# A workflow definition (draft or published), as stored JSON:
#
#   { "trigger" => { "type" => "tag_added", "config" => { "tag_id" => 3 } },
#     "entry" => { "match" => "all", "conditions" => [...] },          # Segment::Condition rules, optional
#     "steps" => [ { "id" => "a1b2", "type" => "wait", "config" => { ... } },
#                  { "id" => "c3d4", "type" => "condition", "config" => { ... }, "yes" => [ ... ], "no" => [ ... ] } ] }
#
# Step ids never change, so runs can point at a step across edits and versions.
class Workflow::Definition
  BRANCHES = %w[ yes no ].freeze

  def initialize(hash)
    @hash = hash.to_h.deep_stringify_keys
    @hash["steps"] = Array(@hash["steps"])
    @hash["trigger"] ||= { "type" => nil, "config" => {} }
    @hash["entry"] ||= { "match" => "all", "conditions" => [] }
  end

  def to_h = @hash

  def trigger = Workflow::Trigger.new(@hash["trigger"])
  def trigger=(trigger)
    @hash["trigger"] = trigger.to_h
  end

  def entry = Segment.new(definition: @hash["entry"])
  def entry=(definition)
    @hash["entry"] = Segment.new(definition:).definition
  end

  def entry_conditions? = Array(@hash.dig("entry", "conditions")).any?

  def steps = @hash["steps"]
  def empty? = steps.empty?
  def first_step_id = steps.first&.dig("id")

  def find(id) = locate(id)&.first
  def all_steps(list = steps) = list.flat_map { |step| [ step ] + BRANCHES.flat_map { |branch| all_steps(Array(step[branch])) } }

  # The step after `id`. For a condition, `branch` ("yes"/"no") picks which list to enter;
  # at the end of a branch the run carries on after the condition step.
  def next_step_id(id, branch: nil)
    step, list, index, parent = locate(id)
    return unless step

    if step["type"] == "condition" && branch && (first = Array(step[branch]).first)
      return first["id"]
    end

    loop do
      return list[index + 1]["id"] if list[index + 1]
      return unless parent

      _, list, index, parent = locate(parent["id"])
    end
  end

  # What stops this from being published.
  def errors
    messages = trigger.errors.map { |message| "Trigger #{message}" }
    messages << "Add at least one step" if empty?
    entry.conditions.each_with_index do |condition, index|
      condition.errors.each { |message| messages << "Entry condition #{index + 1} #{message}" }
    end
    all_steps.each_with_index do |step, index|
      Workflow::Steps.for(step).errors.each { |message| messages << "Step #{index + 1} (#{Workflow::Steps.label(step["type"])}): #{message}" }
    end
    messages
  end

  # --- Editing (the builder) ---

  def insert(step, parent_id: nil, branch: nil)
    list_for(parent_id, branch) << step
  end

  def update_config(id, config)
    find(id)&.store("config", config.to_h)
  end

  def remove(id)
    _, list, index = locate(id)
    list&.delete_at(index)
  end

  def move(id, new_index)
    step, list, index = locate(id)
    return unless step

    list.delete_at(index)
    list.insert(new_index.to_i.clamp(0, list.size), step)
  end

  private
    def list_for(parent_id, branch)
      return steps unless parent_id

      parent = find(parent_id)
      raise ArgumentError, "Steps can only go inside a condition's yes or no branch" unless parent&.dig("type") == "condition" && BRANCHES.include?(branch)

      parent[branch] = Array(parent[branch])
    end

    # [step, the list holding it, its index, the condition step whose branch holds the list]
    def locate(id, list = steps, parent = nil)
      list.each_with_index do |step, index|
        return [ step, list, index, parent ] if step["id"] == id

        BRANCHES.each do |branch|
          found = locate(id, Array(step[branch]), step)
          return found if found
        end
      end
      nil
    end
end
