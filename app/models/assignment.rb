# A person scheduled to a position at a service or event occurrence.
class Assignment < ApplicationRecord
  include AffectsPathway

  SCHEDULABLE_TYPES = %w[ ServiceOccurrence EventOccurrence ].freeze

  belongs_to :schedulable, polymorphic: true
  belongs_to :position
  belongs_to :person
  belongs_to :assigned_by, class_name: "User", optional: true
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  has_secure_token :response_token

  enum :status, { pending: "pending", accepted: "accepted", declined: "declined" }, default: :pending, validate: true

  validates :schedulable_type, inclusion: { in: SCHEDULABLE_TYPES }
  validates :person_id, uniqueness: { scope: %i[ schedulable_type schedulable_id position_id ], message: "is already scheduled here" }
  validate :schedulable_in_this_church

  before_validation { self.local_date = schedulable&.local_date if schedulable }

  scope :active, -> { where.not(status: "declined") }
  scope :on, ->(date) { where(local_date: date) }
  scope :upcoming, ->(today) { where(local_date: today..).order(:local_date) }
  scope :awaiting_request, -> { pending.where(requested_at: nil) }

  delegate :starts_at, :ends_at, :title, to: :schedulable
  delegate :team, to: :position

  def accept! = respond!(:accepted)
  def decline! = respond!(:declined)

  # Email links work until the occurrence is over.
  def respondable? = schedulable.ends_at.future?

  def mark_requested!
    update!(requested_at: Time.current)
  end

  private
    def respond!(status)
      update!(status:, responded_at: Time.current)
    end

    # Polymorphic belongs_to isn't covered by acts_as_tenant's association check.
    def schedulable_in_this_church
      errors.add(:schedulable, "must belong to this church") if schedulable && schedulable.church_id != church_id
    end
end
