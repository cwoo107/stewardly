# A saved, reusable filter over people: campaign audiences, workflow entry
# conditions, report scopes, and map filters. Segment::Query turns the
# definition into one SQL query.
class Segment < ApplicationRecord
  belongs_to :created_by, class_name: "User", optional: true
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  validates :name, presence: true
  validates_uniqueness_to_tenant :name
  validate :definition_is_valid

  scope :alphabetical, -> { order(:name) }

  def conditions
    Array(definition["conditions"]).map { |attributes| Segment::Condition.new(attributes) }
  end

  def match
    definition["match"] == "any" ? "any" : "all"
  end

  def people
    Segment::Query.new(match:, conditions:).people
  end

  # Accepts form params: { match:, conditions: { "0" => { type:, ... }, ... } } or an array.
  def definition=(value)
    value = value.to_h.deep_stringify_keys
    conditions = value["conditions"]
    conditions = conditions.values if conditions.is_a?(Hash)
    super("match" => value["match"] == "any" ? "any" : "all",
      "conditions" => Array(conditions).map { |c| Segment::Condition.new(c).to_h })
  end

  private
    def definition_is_valid
      conditions.each_with_index do |condition, index|
        condition.errors.each { |message| errors.add(:definition, "condition #{index + 1}: #{message}") }
      end
    end
end
