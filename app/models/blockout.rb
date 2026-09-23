# Dates a person can't serve.
class Blockout < ApplicationRecord
  belongs_to :person
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  validates :starts_on, :ends_on, presence: true
  validate :ends_after_start

  before_validation { self.ends_on ||= starts_on }

  scope :covering, ->(date) { where(starts_on: ..date, ends_on: date..) }
  scope :current, ->(today) { where(ends_on: today..).order(:starts_on) }

  def covers?(date) = (starts_on..ends_on).cover?(date)

  private
    def ends_after_start
      errors.add(:ends_on, "can't be before the start") if starts_on && ends_on && ends_on < starts_on
    end
end
