class GroupMembership < ApplicationRecord
  include AffectsPathway

  belongs_to :group
  belongs_to :person
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  enum :role, { member: "member", leader: "leader" }, default: :member, validate: true

  validates :person_id, uniqueness: { scope: :group_id, message: "is already in this group" }
  validate :group_has_room, on: :create

  before_validation { self.joined_on ||= church&.today || Date.current }
  after_create_commit { Workflow::Events.publish("group_joined", person:, subject: self) }

  private
    def group_has_room
      errors.add(:base, "#{group.name} is full") if group&.full?
    end
end
