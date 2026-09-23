# Shared by records with a street address and a geography(Point, 4326) `location`:
# Household, Group, and Campus. Geocoding always happens in GeocodeJob, never inline.
module Geocodable
  extend ActiveSupport::Concern

  ADDRESS_ATTRIBUTES = %w[ address_line1 address_line2 city region postal_code country ].freeze
  POINT_FACTORY = RGeo::Geographic.spherical_factory(srid: 4326)

  included do
    # Skipped when the same save also set a location (seeds, imports with coordinates).
    after_commit :enqueue_geocoding, on: %i[ create update ],
      if: -> { saved_changes.keys.intersect?(ADDRESS_ATTRIBUTES) && !saved_change_to_location? }

    scope :located, -> { where.not(location: nil) }
  end

  class_methods do
    def point(latitude:, longitude:)
      POINT_FACTORY.point(longitude, latitude)
    end
  end

  def full_address
    [ address_line1, address_line2, city, [ region, postal_code ].compact_blank.join(" "), country ].compact_blank.join(", ")
  end

  def address?
    address_line1.present? && (city.present? || postal_code.present?)
  end

  def latitude = location&.latitude
  def longitude = location&.longitude

  # Called by GeocodeJob. Safe to repeat: it always geocodes the current address.
  def geocode!
    return update_columns(location: nil, geocoded_at: nil, geocode_error: nil) unless address?

    if (result = Geocoder.search(full_address).first)
      update_columns(location: self.class.point(latitude: result.latitude, longitude: result.longitude),
        geocoded_at: Time.current, geocode_error: nil)
    else
      update_columns(geocode_error: "Address not found", geocoded_at: Time.current)
    end
  end

  private
    def enqueue_geocoding
      GeocodeJob.perform_later(self)
    end
end
