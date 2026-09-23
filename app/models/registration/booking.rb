# Books a person onto an event occurrence: a seat if there's room, otherwise the
# waitlist. The occurrence is locked, so two people can't both take the last seat.
# Booking the same person twice returns their existing registration.
class Registration::Booking
  Result = Data.define(:registration, :created) do
    def waitlisted? = registration.waitlisted?
  end

  def initialize(occurrence:, person:, party_size: 1, form_submission: nil)
    @occurrence = occurrence
    @person = person
    @party_size = party_size.to_i.clamp(1, 20)
    @form_submission = form_submission
  end

  def book!
    result = @occurrence.with_lock do
      existing = @occurrence.registrations.active.find_by(person: @person)
      next Result.new(existing, false) if existing

      status = @occurrence.fits?(@party_size) ? :confirmed : :waitlisted
      Result.new(@occurrence.registrations.create!(person: @person, party_size: @party_size, status:, form_submission: @form_submission), true)
    end

    notify(result.registration) if result.created
    result
  end

  private
    def notify(registration)
      (registration.confirmed? ? RegistrationMailer.confirmed(registration) : RegistrationMailer.waitlisted(registration)).deliver_later
    end
end
