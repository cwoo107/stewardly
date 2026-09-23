# Records that pathway stage rules read (group and team memberships, enrollments,
# assignments, check-ins, tags). Changing one re-places that person.
module AffectsPathway
  extend ActiveSupport::Concern

  included do
    after_commit :place_person_on_pathway
  end

  private
    def place_person_on_pathway
      PathwayPlacementJob.perform_later(person) if person_id && Person.exists?(person_id)
    end
end
