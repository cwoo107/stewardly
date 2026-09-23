# One run of a course (e.g. "Membership 101, fall"), with sessions, a leader, and enrollments.
class CourseOffering < ApplicationRecord
  include Waitlistable

  belongs_to :course, inverse_of: :offerings
  belongs_to :leader, class_name: "Person", optional: true
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  has_many :sessions, -> { order(:starts_at) }, class_name: "CourseSession", dependent: :destroy, inverse_of: :course_offering
  has_many :enrollments, dependent: :destroy

  validates :starts_on, presence: true
  validates :capacity, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :ends_after_start

  scope :open_for_enrollment, ->(today) { where(enrollment_open: true).where("ends_on IS NULL OR ends_on >= ?", today) }
  scope :chronological, -> { order(:starts_on) }

  delegate :name, :ministry, to: :course

  def title = "#{course.name} (#{I18n.l(starts_on, format: :long)})"

  def capacity_limit = capacity
  def seated_bookings = enrollments.where(status: %w[ enrolled completed ])
  def waiting_bookings = enrollments.waitlisted.order(:created_at, :id)
  def seats_for(_enrollment) = 1
  def seat!(enrollment) = enrollment.update!(status: :enrolled, promoted_at: Time.current)

  private
    def ends_after_start
      errors.add(:ends_on, "can't be before the start") if starts_on && ends_on && ends_on < starts_on
    end
end
