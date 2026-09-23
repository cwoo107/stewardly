# Places people on the pathway from facts: each person goes to the highest stage
# whose rules they meet (the first stage has none). People move back when the facts
# lapse. Only changes are written, each with a PathwayTransition; repeating is a no-op.
#
#   Pathway::Placement.new(pathway).place_everyone!
#   Pathway::Placement.new(pathway).place!(person)
class Pathway::Placement
  def initialize(pathway, now: nil)
    @pathway = pathway
    # Saved stages only, straight from the database: an unsaved stage built on the
    # pathway (a "new" form, or has_many_inversing) must never become a placement target.
    @stages = PathwayStage.where(pathway:).ordered.to_a
    @fixed_now = now
  end

  def place_everyone!
    apply(targets(Person.unmerged))
  end

  def place!(person)
    return PathwayPlacement.where(person:).delete_all if person.merged?

    apply(targets(Person.where(id: person.id)))
  end

  # How many people each stage would hold with some stages' rules replaced (nothing is saved).
  #   preview(stage_id => definition) # => { stage => count }
  def preview(overrides = {})
    counts = targets(Person.unmerged, overrides:).values.tally
    @stages.to_h { |stage| [ stage, counts[stage.id].to_i ] }
  end

  private
    # person id => stage id, highest qualifying stage first; one query per stage.
    def targets(people, overrides: {})
      ids = people.pluck(:id)
      placed = {}
      @stages.drop(1).reverse_each do |stage|
        definition = overrides.fetch(stage.id, stage.definition)
        qualifying = Segment.new(definition:).then { |segment| Segment::Query.new(match: segment.match, conditions: segment.conditions).people }
        qualifying.where(id: ids - placed.keys).pluck(:id).each { |id| placed[id] = stage.id }
      end
      (ids - placed.keys).each { |id| placed[id] = @stages.first.id }
      placed
    end

    def apply(targets)
      @now = @fixed_now || Time.current
      existing = PathwayPlacement.where(person_id: targets.keys).index_by(&:person_id)
      positions = @stages.to_h { |stage| [ stage.id, stage.position ] }
      created_at = Person.where(id: targets.keys - existing.keys).pluck(:id, :created_at).to_h

      PathwayPlacement.transaction do
        targets.each do |person_id, stage_id|
          placement = existing[person_id]
          if placement.nil?
            entered_at = stage_id == @stages.first.id ? [ created_at[person_id], @now ].compact.min : @now
            PathwayPlacement.create!(person_id:, pathway_stage_id: stage_id, entered_at:, evaluated_at: @now)
            PathwayTransition.create!(person_id:, to_stage_id: stage_id, direction: :placed, occurred_at: entered_at)
          elsif placement.pathway_stage_id != stage_id
            direction = positions[stage_id] > positions.fetch(placement.pathway_stage_id, -1) ? :forward : :back
            PathwayTransition.create!(person_id:, from_stage_id: placement.pathway_stage_id, to_stage_id: stage_id, direction:, occurred_at: @now)
            placement.update!(pathway_stage_id: stage_id, entered_at: @now, evaluated_at: @now)
          end
        end
        PathwayPlacement.where(person_id: targets.keys).update_all(evaluated_at: @now)
      end
      targets
    end
end
