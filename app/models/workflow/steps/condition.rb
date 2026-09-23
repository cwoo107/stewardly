# Checks the person against segment-style rules and follows the "yes" or "no" branch.
class Workflow::Steps::Condition < Workflow::Steps::Base
  self.label = "If / else"
  self.default_config = { "match" => "all", "conditions" => [] }

  def rules = Segment.new(definition: config)

  def errors
    rules.conditions.empty? ? [ "needs at least one rule" ] : rules.conditions.flat_map(&:errors)
  end

  def summary
    conditions = rules.conditions
    return "If… (no rules yet)" if conditions.empty?

    "If #{conditions.map(&:summary).join(rules.match == "any" ? " or " : " and ")}"
  end

  def perform(run, _execution)
    matched = rules.people.where(id: run.person_id).exists?
    Outcome.branch(matched ? "yes" : "no", "matched" => matched)
  end
end
