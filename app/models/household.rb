class Household < ApplicationRecord
  include Geocodable

  # Approximate locations snap to a grid of this many degrees (about 1 km).
  APPROXIMATE_GRID_DEGREES = 0.01

  acts_as_tenant :church

  has_many :people, -> { unmerged }, dependent: :nullify, inverse_of: :household

  validates :name, presence: true

  scope :alphabetical, -> { order(:name) }
  scope :search, ->(term) {
    next all if term.blank?

    pattern = "%#{sanitize_sql_like(term.strip)}%"
    where("households.name ILIKE :pattern OR households.address_line1 ILIKE :pattern OR households.city ILIKE :pattern", pattern:)
  }

  # Groups ordered nearest first (KNN on the GiST index).
  def nearest_groups(limit: 5)
    return Group.none unless location

    Group.active.nearest_to(location).limit(limit)
  end

  # Coordinates for display. Users without view_precise_locations get the point
  # snapped to a ~1 km grid, computed in the database.
  def display_location_for(user)
    return unless location
    return [ latitude, longitude ] if user.can?(:view_precise_locations)

    snapped = self.class.where(id:).pick(
      Arel.sql("ST_Y(ST_SnapToGrid(location::geometry, #{APPROXIMATE_GRID_DEGREES}))"),
      Arel.sql("ST_X(ST_SnapToGrid(location::geometry, #{APPROXIMATE_GRID_DEGREES}))"))
    snapped.map(&:to_f)
  end
end
