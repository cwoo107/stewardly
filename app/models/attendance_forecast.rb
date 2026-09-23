# A stored forecast for one service occurrence. Refreshed until the service
# starts, then frozen, so accuracy compares what we actually predicted.
class AttendanceForecast < ApplicationRecord
  MODEL_VERSION = "1"

  belongs_to :service_occurrence
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  validates :expected, :low, :high, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  delegate :local_date, :attendance_count, to: :service_occurrence

  def frozen? = frozen_at.present?
  def expected_in_person = expected_online && expected - expected_online

  def actual = attendance_count&.total

  def error_percent
    actual.to_i.positive? ? ((expected - actual).abs * 100.0 / actual) : nil
  end

  def within_range? = actual && actual.between?(low, high)
end
