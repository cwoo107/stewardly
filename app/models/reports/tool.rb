# A read-only metric the report assistant (and the Metrics page) can run. Each tool is
# tenant-scoped, checks the user's permission, and returns structured numbers:
#
#   Result#figures  { "People who joined" => 84, "Connected to a group (%)" => 13 }
#   Result#tables   [{ "title" =>, "columns" => [...], "rows" => [[...], ...] }]
#
# The AI only sees each tool's name, description, and parameter schema, and the results.
class Reports::Tool
  Result = Data.define(:figures, :tables, :note) do
    def self.build(figures: {}, tables: [], note: nil) = new(figures:, tables:, note:)
    def to_h = { "figures" => figures, "tables" => tables, "note" => note }.compact
  end

  class_attribute :tool_name, :title, :description, :permission
  class_attribute :parameters, default: {}

  def self.available_to?(user, church) = user.can?(permission)

  # For the AI: an Ollama/OpenAI-style function definition.
  def self.definition
    { type: "function", function: { name: tool_name, description:,
      parameters: { type: "object", properties: parameters.transform_values { |spec| spec.except(:label, :default) }, required: [] } } }
  end

  def initialize(church:, user:)
    @church = church
    @user = user
    @today = church.today
  end

  # Runs with arguments from the AI or a form (strings are fine); unknown keys are ignored
  # and missing ones get their defaults. #arguments is what was actually used.
  def run(arguments)
    @arguments = normalize(arguments.to_h.stringify_keys)
    call(@arguments)
  end

  def arguments = @arguments.to_h.transform_values { |value| value.respond_to?(:iso8601) ? value.iso8601 : value }

  private
    def call(_args) = raise(NotImplementedError)

    def normalize(arguments)
      parameters.to_h do |key, spec|
        raw = arguments[key.to_s]
        value = case spec[:type]
        when "integer" then Integer(raw.to_s, exception: false)
        when "string" then spec[:enum] ? raw.to_s.presence_in(spec[:enum]) : (spec[:format] == "date" ? parse_date(raw) : raw.to_s.strip.presence)
        end
        [ key.to_s, value.nil? ? default_for(spec) : value ]
      end
    end

    def default_for(spec) = spec[:default].respond_to?(:call) ? instance_exec(&spec[:default]) : spec[:default]
    def parse_date(raw) = raw.present? ? (Date.iso8601(raw.to_s) rescue nil) : nil
    def percent(part, whole) = whole.to_i.zero? ? 0 : (part * 100.0 / whole).round(1)
    def table(title, columns, rows) = { "title" => title, "columns" => columns, "rows" => rows }
end
