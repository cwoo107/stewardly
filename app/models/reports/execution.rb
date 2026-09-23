# Runs one tool call for a user, permission-checked. Returns the recorded call:
#   { "name", "title", "arguments", "requested", "result" } or { "name", "arguments", "error" }
module Reports::Execution
  def self.run(name, arguments, user:, church:)
    tool = Reports::Tools.find(name, user:, church:)
    return { "name" => name.to_s, "arguments" => arguments.to_h, "error" => "No tool called #{name} is available to you" } unless tool

    # A savepoint, so a failing query can't leave the surrounding transaction unusable.
    instance = tool.new(church:, user:)
    result = ActiveRecord::Base.transaction(requires_new: true) { instance.run(arguments.to_h) }
    # arguments: what was used (defaults filled in); requested: what was asked, which saved
    # reports keep so relative defaults ("this year", "today") stay relative on re-runs.
    { "name" => tool.tool_name, "title" => tool.title, "arguments" => instance.arguments, "requested" => arguments.to_h.stringify_keys, "result" => result.to_h }
  rescue ActiveRecord::ActiveRecordError, ArgumentError, TypeError => error
    { "name" => name.to_s, "arguments" => arguments.to_h, "error" => "#{error.class}: #{error.message}".first(300) }
  end
end
