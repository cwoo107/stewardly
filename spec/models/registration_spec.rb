require "rails_helper"

RSpec.describe Registration do
  include ActiveJob::TestHelper

  it_behaves_like "a tenant-scoped model"

  let(:event) { create(:event, :registration, capacity: 2, max_party_size: 4) }
  let(:occurrence) { create(:event_occurrence, event:) }

  describe Registration::Booking do
    def book(person = create(:person), party_size: 1) = Registration::Booking.new(occurrence:, person:, party_size:).book!

    it "confirms while there's room, counting party size, then waitlists" do
      first = book(party_size: 2)
      second = book

      expect(first.registration).to be_confirmed
      expect(second.registration).to be_waitlisted
      expect(occurrence.seats_left).to eq(0)
    end

    it "returns the existing registration for a repeat booking" do
      person = create(:person)
      original = book(person).registration
      again = book(person)
      expect(again.registration).to eq(original)
      expect(again.created).to be(false)
    end

    it "emails a confirmation or waitlist notice" do
      expect { book(party_size: 2) }.to have_enqueued_mail(RegistrationMailer, :confirmed)
      expect { book }.to have_enqueued_mail(RegistrationMailer, :waitlisted)
    end

    it "limits party size to the event's maximum" do
      expect { book(party_size: 5) }.to raise_error(ActiveRecord::RecordInvalid, /at most 4/)
    end
  end

  it "promotes the waitlist when someone cancels" do
    event.update!(capacity: 1)
    seated = Registration::Booking.new(occurrence:, person: create(:person)).book!.registration
    waiting = Registration::Booking.new(occurrence:, person: create(:person)).book!.registration

    expect { seated.cancel! }.to have_enqueued_mail(RegistrationMailer, :promoted)
    expect(waiting.reload).to have_attributes(status: "confirmed", promoted_at: be_present)
  end

  it "skips waitlisted parties too big for the freed seats" do
    event.update!(capacity: 2)
    seated = Registration::Booking.new(occurrence:, person: create(:person)).book!.registration
    Registration::Booking.new(occurrence:, person: create(:person)).book!
    big = Registration::Booking.new(occurrence:, person: create(:person), party_size: 3).book!.registration

    seated.cancel!
    expect(big.reload).to be_waitlisted
  end
end
