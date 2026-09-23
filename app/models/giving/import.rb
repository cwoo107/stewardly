# Saves provider records: funds by external id, donations by external id (so importing
# the same gift twice changes nothing, and a later refund updates the original), then
# matches new gifts to people.
class Giving::Import
  Counts = Struct.new(:created, :updated, :matched, :unmatched) do
    def self.zero = new(0, 0, 0, 0)
  end

  def initialize(integration)
    @integration = integration
    @provider = integration.provider
  end

  def import_funds(records)
    records.each do |record|
      fund = Fund.find_or_initialize_by(provider: @provider, external_id: record.external_id)
      fund.update!(name: record.name, active: record.active)
    end
  end

  def import_donations(records, counts: Counts.zero)
    records.each do |record|
      donation = Donation.find_or_initialize_by(provider: @provider, external_id: record.external_id)
      new_record = donation.new_record?
      donation.assign_attributes(
        donor_external_id: record.donor_external_id, donor_name: record.donor_name, donor_email: record.donor_email&.downcase,
        fund: fund_for(record.fund_external_id), amount_cents: record.amount_cents, currency: record.currency.to_s.upcase.presence || "USD",
        given_on: record.given_on, method: record.method, status: record.status)
      next unless donation.changed?

      donation.save!
      new_record ? counts.created += 1 : counts.updated += 1
      next unless new_record

      Giving::Matching.new(donation).match! ? counts.matched += 1 : counts.unmatched += 1
    end
    counts
  end

  private
    def fund_for(external_id)
      return if external_id.blank?

      @funds ||= {}
      @funds[external_id] ||= Fund.find_or_create_by!(provider: @provider, external_id:) { |fund| fund.name = "Fund #{external_id}" }
    end
end
