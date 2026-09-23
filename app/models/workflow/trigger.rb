# What starts a workflow. Event triggers fire from model callbacks (Workflow::Events);
# missed_weeks and date_relative are checked by the daily sweep (Workflow::Sweep).
class Workflow::Trigger
  TYPES = {
    "person_created" => "A person is added",
    "form_submitted" => "A form is submitted",
    "tag_added" => "A tag is added",
    "group_joined" => "Someone joins a group",
    "pathway_stage_changed" => "Pathway stage changes",
    "first_visit" => "First visit to a service",
    "missed_weeks" => "Missed several weeks",
    "date_relative" => "A number of days before or after a date"
  }.freeze

  ATTRIBUTES = {
    "form_submitted" => %w[ form_id ],
    "tag_added" => %w[ tag_id ],
    "group_joined" => %w[ group_id ],
    "pathway_stage_changed" => %w[ stage_id direction ],
    "missed_weeks" => %w[ weeks ],
    "date_relative" => %w[ date_field days ]
  }.freeze

  SWEPT = %w[ missed_weeks date_relative ].freeze
  DIRECTIONS = { "any" => "Any change", "forward" => "Moves forward", "back" => "Moves back" }.freeze

  attr_reader :type, :config

  def initialize(hash)
    hash = hash.to_h.stringify_keys
    @type = hash["type"].to_s.presence
    @config = Array(ATTRIBUTES[@type]).to_h { |key| [ key, hash.dig("config", key).presence ] }.compact
  end

  def to_h = { "type" => type, "config" => config }
  def label = TYPES.fetch(type.to_s, "Not set")
  def swept? = SWEPT.include?(type)
  def [](key) = config[key.to_s]

  def errors
    return [ "isn't chosen" ] unless TYPES.key?(type)

    case type
    when "form_submitted" then Form.where.not(purpose: "benevolence_request").exists?(config["form_id"]) ? [] : [ "needs a form" ]
    when "tag_added" then Tag.exists?(config["tag_id"]) ? [] : [ "needs a tag" ]
    when "missed_weeks" then config["weeks"].to_i.between?(1, 52) ? [] : [ "needs a number of weeks (1–52)" ]
    when "date_relative"
      problems = []
      problems << "needs a date" unless Workflow::DateFields.options.value?(config["date_field"])
      problems << "needs a number of days (-365 to 365)" unless config["days"].to_s.match?(/\A-?\d+\z/) && config["days"].to_i.abs <= 365
      problems
    else []
    end
  end

  # Does an event of this trigger's type, about this subject, match its settings?
  def matches?(subject)
    case type
    when "form_submitted" then subject.form_id.to_s == config["form_id"].to_s
    when "tag_added" then subject.tag_id.to_s == config["tag_id"].to_s
    when "group_joined" then config["group_id"].blank? || subject.group_id.to_s == config["group_id"].to_s
    when "pathway_stage_changed"
      (config["stage_id"].blank? || subject.to_stage_id.to_s == config["stage_id"].to_s) &&
        (config["direction"].in?([ nil, "any" ]) ? !subject.placed? : subject.direction == config["direction"])
    else true
    end
  end

  def summary
    case type
    when "form_submitted" then "#{label}: #{Form.find_by(id: config["form_id"])&.name || "?"}"
    when "tag_added" then "Tagged #{Tag.find_by(id: config["tag_id"])&.name || "?"}"
    when "group_joined" then config["group_id"] ? "Joins #{Group.find_by(id: config["group_id"])&.name || "?"}" : "Joins any group"
    when "pathway_stage_changed"
      stage = PathwayStage.find_by(id: config["stage_id"])&.name
      [ DIRECTIONS.fetch(config["direction"] || "any"), (" to #{stage}" if stage) ].join.then { |text| "Pathway: #{text.downcase}" }
    when "missed_weeks" then "Missed #{config["weeks"]} weeks in a row"
    when "date_relative"
      days = config["days"].to_i
      field = Workflow::DateFields.options.key(config["date_field"]) || "?"
      days.zero? ? "On their #{field.downcase}" : "#{days.abs} days #{days.negative? ? "before" : "after"} their #{field.downcase}"
    else label
    end
  end
end
