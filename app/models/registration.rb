class Registration < ApplicationRecord
  belongs_to :event_occurrence
  belongs_to :person
  belongs_to :form_submission, optional: true
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  has_secure_token :manage_token

  enum :status, { confirmed: "confirmed", waitlisted: "waitlisted", cancelled: "cancelled" }, default: :confirmed, validate: true

  validates :party_size, numericality: { only_integer: true, greater_than: 0 }
  validate :party_size_within_event_limit, on: :create

  scope :active, -> { where.not(status: "cancelled") }

  delegate :event, to: :event_occurrence

  def checked_in? = checked_in_at.present?

  def check_in!
    update!(checked_in_at: Time.current)
  end

  def undo_check_in!
    update!(checked_in_at: nil)
  end

  # Cancels and hands the freed seats to the waitlist. Returns promoted registrations.
  def cancel!
    event_occurrence.with_lock do
      update!(status: :cancelled, cancelled_at: Time.current)
      event_occurrence.promote_waitlist!
    end.tap { |promoted| promoted.each { |registration| RegistrationMailer.promoted(registration).deliver_later } }
  end

  private
    def party_size_within_event_limit
      errors.add(:party_size, "can be at most #{event.max_party_size}") if party_size.to_i > event_occurrence.event.max_party_size
    end
end
