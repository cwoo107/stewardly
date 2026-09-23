# Capacity and first-come waitlists, shared by event occurrences (registrations,
# counted by party size) and course offerings (enrollments, one seat each).
#
# The including model defines:
#   capacity_limit   # nil = unlimited
#   seated_bookings  # relation of bookings holding seats
#   waiting_bookings # relation of waitlisted bookings, oldest first
#   seats_for(booking)
#   seat!(booking)   # moves a waitlisted booking into a seat
module Waitlistable
  extend ActiveSupport::Concern

  def seats_taken
    seated_bookings.sum { |booking| seats_for(booking) }
  end

  def seats_left
    capacity_limit && [ capacity_limit - seats_taken, 0 ].max
  end

  def fits?(seats)
    capacity_limit.nil? || seats <= seats_left
  end

  def full? = !fits?(1)

  # Seats waitlisted bookings, oldest first, while they fit. Callers hold a lock
  # on this record. Returns the promoted bookings.
  def promote_waitlist!
    waiting_bookings.to_a.each_with_object([]) do |booking, promoted|
      break promoted unless fits?(seats_for(booking))

      seat!(booking)
      promoted << booking
    end
  end
end
