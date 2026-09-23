# A Sunday the church marks as unusual (Back to school, Friend day, Baptism Sunday).
# Days with the same name share a key, so the forecast learns each kind's effect
# across years. An expected change overrides what's learned.
class SpecialSunday < ApplicationRecord
  acts_as_tenant :church

  normalizes :name, with: ->(name) { name.squish }

  before_validation { self.key = name.to_s.parameterize if name.present? }

  validates :name, :local_date, presence: true
  validates_uniqueness_to_tenant :local_date, message: "already has a special Sunday"
  validates :expected_change_percent, numericality: { only_integer: true, in: -90..300 }, allow_nil: true

  scope :chronological, -> { order(:local_date) }
end
