# Combines segment conditions into a single relation over (unmerged) people.
#   Segment::Query.new(match: "all", conditions: [...]).people  # => ActiveRecord::Relation
# The result is chainable (pagination, counts, plucks) and runs as one SQL query.
class Segment::Query
  def initialize(match: "all", conditions: [])
    @match = match.to_s == "any" ? "any" : "all"
    @conditions = conditions.map { |condition| condition.is_a?(Segment::Condition) ? condition : Segment::Condition.new(condition) }
  end

  def people
    valid = @conditions.select(&:valid?)
    return Person.unmerged if valid.empty?

    relations = valid.map(&:relation)
    @match == "any" ? relations.reduce(:or) : relations.reduce(:and)
  end
end
