# A field's show/hide rule, evaluated against rule values (see FormField#rule_value).
# The browser evaluates the same JSON with the same semantics in
# app/javascript/controllers/form_logic_controller.js; spec/fixtures/files/form_rules.json
# is run through both.
#
#   { "match" => "all" | "any", "conditions" => [{ "field" => "key", "operator" => "equals", "value" => "Yes" }] }
class Form::Rule
  OPERATORS = {
    "equals" => "is", "not_equals" => "is not", "contains" => "contains",
    "filled" => "is filled in", "empty" => "is empty", "greater_than" => "is more than", "less_than" => "is less than"
  }.freeze
  VALUELESS = %w[ filled empty ].freeze
  # Plain decimal numbers only, so Ruby and JavaScript agree on what's a number.
  NUMBER = /\A[+-]?(\d+(\.\d*)?|\.\d+)\z/
  ISO_DATE = /\A\d{4}-\d{2}-\d{2}\z/

  def self.normalize(value)
    hash = value.respond_to?(:to_unsafe_h) ? value.to_unsafe_h : value.to_h
    hash = hash.deep_stringify_keys
    conditions = hash["conditions"]
    conditions = conditions.values if conditions.is_a?(Hash)
    conditions = Array(conditions).filter_map do |condition|
      condition = condition.to_h.stringify_keys
      next if condition["field"].blank? || condition["_destroy"] == "1"

      { "field" => condition["field"].to_s, "operator" => condition["operator"].to_s,
        "value" => VALUELESS.include?(condition["operator"]) ? "" : condition["value"].to_s.strip }
    end
    conditions.empty? ? {} : { "match" => hash["match"] == "any" ? "any" : "all", "conditions" => conditions }
  end

  def initialize(definition)
    @definition = definition.to_h
  end

  def conditions = Array(@definition["conditions"])

  # "Shown when First visit is filled in and Age is more than 17"
  def summary(labels)
    return "Always shown" if always?

    parts = conditions.map do |condition|
      [ labels.fetch(condition["field"], condition["field"]), OPERATORS.fetch(condition["operator"], condition["operator"]),
        condition["value"].presence&.then { |value| "“#{value}”" } ].compact.join(" ")
    end
    "Shown when #{parts.join(match == "any" ? " or " : " and ")}"
  end
  def match = @definition["match"] == "any" ? "any" : "all"
  def always? = conditions.empty?

  def errors(available_keys:)
    conditions.filter_map do |condition|
      next "uses an unknown comparison" unless OPERATORS.key?(condition["operator"])
      next "refers to a field that isn't on this form" unless available_keys.include?(condition["field"])

      "needs a value to compare with" if !VALUELESS.include?(condition["operator"]) && condition["value"].to_s.empty?
    end
  end

  # answers: { field key => rule value }; missing keys count as empty.
  def satisfied_by?(answers)
    return true if always?

    results = conditions.map { |condition| holds?(condition, answers[condition["field"]]) }
    match == "any" ? results.any? : results.all?
  end

  private
    def holds?(condition, answer)
      expected = condition["value"].to_s
      case condition["operator"]
      when "filled" then filled?(answer)
      when "empty" then !filled?(answer)
      when "equals" then equals?(answer, expected)
      when "not_equals" then !equals?(answer, expected)
      when "contains" then answer.is_a?(Array) ? equals?(answer, expected) : answer.to_s.downcase.include?(expected.downcase)
      when "greater_than" then compare(answer, expected)&.positive? || false
      when "less_than" then compare(answer, expected)&.negative? || false
      else false
      end
    end

    def filled?(answer)
      answer.is_a?(Array) ? answer.any? : !answer.to_s.empty?
    end

    def equals?(answer, expected)
      if answer.is_a?(Array)
        answer.any? { |item| item.casecmp?(expected) }
      else
        answer.to_s.casecmp?(expected)
      end
    end

    # Numbers compare numerically; ISO dates (YYYY-MM-DD) compare as dates; anything else doesn't compare.
    def compare(answer, expected)
      return if answer.is_a?(Array) || answer.to_s.empty?

      a, b = answer.to_s.strip, expected.strip
      return a.to_f <=> b.to_f if a.match?(NUMBER) && b.match?(NUMBER)

      a <=> b if a.match?(ISO_DATE) && b.match?(ISO_DATE)
    end
end
