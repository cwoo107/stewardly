# One step on the pathway. Its rules use the segment format ({match, conditions}):
# a person is at the highest stage whose rules they meet; everyone meets the first.
class PathwayStage < ApplicationRecord
  include Positionable

  belongs_to :pathway, inverse_of: :stages
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  positioned within: :pathway_id

  has_many :placements, class_name: "PathwayPlacement", dependent: :restrict_with_error

  validates :name, presence: true
  validates :stuck_after_days, numericality: { only_integer: true, in: 7..3650 }, allow_nil: true
  validate :rules_are_valid

  def definition=(value)
    super(Segment.new(definition: value).definition)
  end

  def conditions = Segment.new(definition:).conditions
  def match = Segment.new(definition:).match

  def first? = pathway.first_stage == self
  def last? = pathway.last_stage == self

  # People who meet this stage's rules (everyone, for a stage without rules).
  def qualifying_people
    Segment::Query.new(match:, conditions:).people
  end

  private
    def rules_are_valid
      conditions.each_with_index do |condition, index|
        condition.errors.each { |message| errors.add(:definition, "rule #{index + 1}: #{message}") }
        errors.add(:definition, "rule #{index + 1}: a stage can't depend on the pathway itself") if Segment::Condition::PATHWAY_TYPES.include?(condition.type)
      end
    end
end
