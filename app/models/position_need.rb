# How many people a position needs at a service (every week) or an event (each date).
class PositionNeed < ApplicationRecord
  belongs_to :needable, polymorphic: true
  belongs_to :position
  # Declared after belongs_to so acts_as_tenant also validates those associations belong to this church.
  acts_as_tenant :church

  validates :quantity, numericality: { only_integer: true, in: 1..100 }
  validates :position_id, uniqueness: { scope: %i[ needable_type needable_id ], message: "already has a need here" }
end
