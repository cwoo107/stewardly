# Who may serve in a position. A position without qualifications is open to its whole team.
class PositionQualification < ApplicationRecord
  belongs_to :position
  belongs_to :person
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  validates :person_id, uniqueness: { scope: :position_id }
  validate :person_is_on_the_team

  private
    def person_is_on_the_team
      return unless position && person

      errors.add(:person, "must be on the #{position.team.name} team") unless position.team.team_memberships.exists?(person_id:)
    end
end
