require "rails_helper"

# Real concurrent bookings need committed data visible to two connections, so this
# group runs outside the usual per-example transaction and cleans up after itself.
RSpec.describe Registration::Booking, "when two people book the last seat at once" do
  self.use_transactional_tests = false

  after do
    ActsAsTenant.test_tenant = nil
    tables = ActiveRecord::Base.connection.tables - %w[ schema_migrations ar_internal_metadata spatial_ref_sys ]
    ActiveRecord::Base.connection.execute("TRUNCATE #{tables.join(", ")} RESTART IDENTITY CASCADE")
  end

  it "seats one and waitlists the other" do
    occurrence = create(:event_occurrence, event: create(:event, :registration, capacity: 1))
    people = create_list(:person, 2)

    people.map do |person|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ActsAsTenant.with_tenant(church) { described_class.new(occurrence: EventOccurrence.find(occurrence.id), person:).book! }
        end
      end
    end.each(&:join)

    expect(occurrence.registrations.reload.map(&:status)).to contain_exactly("confirmed", "waitlisted")
  end
end
