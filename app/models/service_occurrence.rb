class ServiceOccurrence < ApplicationRecord
  belongs_to :worship_service, inverse_of: :occurrences
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  has_many :assignments, as: :schedulable, dependent: :destroy
  has_one :attendance_count, dependent: :destroy
  has_one :forecast, class_name: "AttendanceForecast", dependent: :destroy
  has_many :attendances, dependent: :delete_all

  scope :upcoming, ->(today) { where(local_date: today..) }
  scope :chronological, -> { order(:starts_at) }

  delegate :position_needs, to: :worship_service

  def title = worship_service.name
end
