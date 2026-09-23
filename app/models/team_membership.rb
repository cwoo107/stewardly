class TeamMembership < ApplicationRecord
  include AffectsPathway

  belongs_to :team
  belongs_to :person
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  enum :role, { member: "member", leader: "leader" }, default: :member, validate: true

  validates :person_id, uniqueness: { scope: :team_id, message: "is already on this team" }
  validates :max_per_month, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
end
