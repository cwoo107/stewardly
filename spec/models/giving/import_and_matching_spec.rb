require "rails_helper"

RSpec.describe Giving::Import do
  let(:integration) { create(:integration, category: "giving", provider: "tithely", credentials: { "api_key" => "k" }, settings: {}) }
  let(:import) { described_class.new(integration) }

  def record(**overrides)
    Giving::Provider::DonationRecord.new(**{ external_id: "t-1", donor_external_id: "d-1", donor_name: "Ada Lovelace", donor_email: "ADA@example.com",
      fund_external_id: "f-1", amount_cents: 2_500, currency: "usd", given_on: Date.new(2026, 9, 6), method: "card", status: "succeeded" }.merge(overrides))
  end

  it "saves each gift once, and updates it when it's refunded" do
    counts = import.import_donations([ record ])
    expect(counts.to_h).to include(created: 1, unmatched: 1)
    import.import_donations([ record ])
    expect(Donation.count).to eq(1)

    counts = import.import_donations([ record(status: "refunded") ])
    expect(counts.updated).to eq(1)
    expect(Donation.last).to have_attributes(status: "refunded", currency: "USD", donor_email: "ada@example.com", fund: have_attributes(external_id: "f-1"))
  end

  it "matches by a known donor link first, then by exactly one person with the email" do
    linked = create(:person)
    create(:donor_link, person: linked, donor_external_id: "d-1")
    ada = create(:person, email: "ada@example.com")
    import.import_donations([ record ])
    expect(Donation.last).to have_attributes(person: linked, match_status: "auto")

    import.import_donations([ record(external_id: "t-2", donor_external_id: "d-2") ])
    expect(Donation.last).to have_attributes(person: ada, match_status: "auto")
    expect(DonorLink.find_by(donor_external_id: "d-2").person).to eq(ada)
  end

  it "leaves gifts unmatched when the email is shared or unknown" do
    create_list(:person, 2, email: "shared@example.com")
    import.import_donations([ record(donor_external_id: nil, donor_email: "shared@example.com") ])
    expect(Donation.last).to be_match_unmatched
  end

  it "learns a donor link from a manual match and matches that donor's other waiting gifts" do
    import.import_donations([ record, record(external_id: "t-2") ])
    person = create(:person, first_name: "Ada", last_name: "Lovelace")
    expect(Giving::Matching.new(Donation.first).suggestions).to include(person)

    Donation.first.match_to!(person)
    expect(Donation.pluck(:person_id).uniq).to eq([ person.id ])
    import.import_donations([ record(external_id: "t-3") ])
    expect(Donation.find_by(external_id: "t-3").person).to eq(person)
  end
end

RSpec.describe Giving::Reconciliation do
  let(:integration) { create(:integration, category: "giving", provider: "tithely", credentials: { "api_key" => "k" }, settings: {}) }
  let(:adapter) { instance_double(Giving::Providers::Tithely) }

  before { allow(integration).to receive(:adapter).and_return(adapter) }

  it "re-fetches from a week before the last reconciliation, and records the run" do
    integration.update!(settings: { "last_reconciled_on" => "2026-09-20" })
    allow(adapter).to receive(:funds).and_return([ Giving::Provider::FundRecord.new("f-1", "General", true) ])
    allow(adapter).to receive(:each_donation).and_yield([])

    run = described_class.new(integration).run!
    expect(adapter).to have_received(:each_donation).with(since: Date.new(2026, 9, 13), until: church.today)
    expect(run).to be_succeeded
    expect(Fund.find_by(external_id: "f-1").name).to eq("General")
    expect(integration.reload.setting(:last_reconciled_on)).to eq(church.today.iso8601)
  end

  it "records a failed run when the provider errors" do
    allow(adapter).to receive(:funds).and_raise(Giving::Provider::Error, "Not yet")
    expect(described_class.new(integration).run!).to have_attributes(status: "failed", error: "Not yet")
  end
end
