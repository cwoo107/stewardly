# Something a stage rule reads changed for this person.
class PathwayPlacementJob < ApplicationJob
  queue_as :low

  discard_on ActiveJob::DeserializationError

  def perform(person)
    Pathway::Placement.new(Pathway.current).place!(person)
  end
end
