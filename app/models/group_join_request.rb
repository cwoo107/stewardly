# A member asking to join a group from the member area; a leader approves or declines.
class GroupJoinRequest < ApplicationRecord
  belongs_to :group
  belongs_to :person
  belongs_to :decided_by, class_name: "User", optional: true
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  enum :status, { pending: "pending", approved: "approved", declined: "declined" }, default: :pending, validate: true

  validates :message, length: { maximum: 1000 }
  validate :not_already_a_member, on: :create

  after_create_commit -> { GroupJoinRequestMailer.received(self).deliver_later }

  def approve!(by:)
    transaction do
      group.group_memberships.create!(person:)
      decide!(:approved, by)
    end
  end

  def decline!(by:)
    decide!(:declined, by)
  end

  private
    def decide!(status, user)
      update!(status:, decided_by: user, decided_at: Time.current)
      GroupJoinRequestMailer.decided(self).deliver_later
    end

    def not_already_a_member
      errors.add(:base, "You're already in this group") if group&.group_memberships&.exists?(person_id:)
    end
end
