# The stages or their rules changed: re-place everyone now rather than at 3am.
class PathwayReplacementJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(pathway)
    Pathway::Placement.new(pathway).place_everyone!
  end
end
