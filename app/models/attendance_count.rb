# The headcount for one service occurrence. With a breakdown by the church's
# categories, the total is their sum.
class AttendanceCount < ApplicationRecord
  belongs_to :service_occurrence
  belongs_to :recorded_by, class_name: "User", optional: true
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  validates :total, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :first_time_guests, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :service_occurrence_id, uniqueness: true
  validate :breakdown_counts_are_whole_numbers

  before_validation :total_from_breakdown

  after_commit -> { AttendanceForecastRefreshJob.perform_later(service_occurrence.worship_service) }, on: %i[ create update ]

  delegate :local_date, to: :service_occurrence

  # Keeps only the church's categories; blanks are dropped.
  def breakdown=(value)
    hash = value.respond_to?(:to_unsafe_h) ? value.to_unsafe_h : value.to_h
    super(hash.transform_values { |count| count.to_s.strip }.compact_blank.transform_values { |count| Integer(count, exception: false) || count })
  end

  def online
    breakdown.sum { |category, count| Church.online_category?(category) ? count.to_i : 0 }
  end

  def in_person = total - online
  def online_known? = breakdown.keys.any? { |category| Church.online_category?(category) }

  private
    def total_from_breakdown
      self.total = breakdown.values.sum(&:to_i) if breakdown.present? && breakdown.values.all?(Integer)
    end

    def breakdown_counts_are_whole_numbers
      bad = breakdown.reject { |_, count| count.is_a?(Integer) && count >= 0 }.keys
      errors.add(:breakdown, "must be whole numbers (#{bad.to_sentence})") if bad.any?
    end
end
