# Where a person is on the pathway now, and since when.
class PathwayPlacement < ApplicationRecord
  belongs_to :person
  belongs_to :pathway_stage
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  validates :person_id, uniqueness: true

  # Longer in a stage than its limit, without moving on. The last stage is never "stuck".
  scope :stuck, -> {
    joins(:pathway_stage).where.not(pathway_stages: { stuck_after_days: nil })
      .where("pathway_placements.entered_at < now() - make_interval(days => pathway_stages.stuck_after_days)")
      .where("pathway_stages.position < (SELECT max(s.position) FROM pathway_stages s WHERE s.pathway_id = pathway_stages.pathway_id)")
  }

  def days_in_stage(now = Time.current) = ((now - entered_at) / 1.day).floor

  def stuck?(now = Time.current)
    limit = pathway_stage.stuck_after_days
    limit.present? && !pathway_stage.last? && days_in_stage(now) > limit
  end
end
