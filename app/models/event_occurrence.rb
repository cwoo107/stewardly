class EventOccurrence < ApplicationRecord
  include Waitlistable

  belongs_to :event, inverse_of: :occurrences
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  has_many :registrations, dependent: :destroy
  has_many :assignments, as: :schedulable, dependent: :destroy

  validates :starts_at, :ends_at, presence: true
  validates :capacity, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :ends_after_start

  before_validation { self.local_date = starts_at.in_time_zone(church.zone).to_date if starts_at && church }

  scope :chronological, -> { order(:starts_at) }
  scope :upcoming, ->(now = Time.current) { where(ends_at: now..).where(cancelled: false) }

  delegate :title, :position_needs, to: :event

  def capacity_limit = capacity || event.capacity
  def seated_bookings = registrations.confirmed
  def waiting_bookings = registrations.waitlisted.order(:created_at, :id)
  def seats_for(registration) = registration.party_size
  def seat!(registration) = registration.update!(status: :confirmed, promoted_at: Time.current)

  def checked_in_count = registrations.confirmed.where.not(checked_in_at: nil).sum(:party_size)

  private
    def ends_after_start
      errors.add(:ends_at, "must be after the start") if starts_at && ends_at && ends_at <= starts_at
    end
end
