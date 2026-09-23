# A recurring service time, e.g. "Sunday 9am". Dated instances are ServiceOccurrences.
class WorshipService < ApplicationRecord
  include ExpiresSiteCache
  belongs_to :campus, optional: true
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  has_many :occurrences, class_name: "ServiceOccurrence", dependent: :destroy, inverse_of: :worship_service
  has_many :position_needs, as: :needable, dependent: :destroy

  validates :name, :start_time, presence: true
  validates :day_of_week, inclusion: { in: 0..6 }
  validates :duration_minutes, numericality: { only_integer: true, in: 5..600 }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:day_of_week, :start_time) }

  # Local dates this service falls on within a range.
  def dates_between(range)
    range.select { |date| date.wday == day_of_week }
  end

  # Start and end times on a local date, in the church's zone (DST-safe).
  def times_on(date)
    starts = church.zone.local(date.year, date.month, date.day, start_time.hour, start_time.min)
    [ starts, starts + duration_minutes.minutes ]
  end

  # Creates any missing occurrences for the range. Safe to repeat.
  def ensure_occurrences!(range)
    existing = occurrences.where(local_date: range).pluck(:local_date)
    (dates_between(range) - existing).each do |date|
      starts_at, ends_at = times_on(date)
      occurrences.create!(local_date: date, starts_at:, ends_at:)
    rescue ActiveRecord::RecordNotUnique
      next
    end
  end
end
