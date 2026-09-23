require "rails_helper"

RSpec.describe "Giving" do
  let(:fund) { create(:fund, name: "General") }

  context "with giving permissions" do
    let(:user) { create(:user, :church_admin) }

    before { sign_in_as(user) }

    it "shows the dashboard, donations, and a CSV export" do
      person = create(:person, first_name: "Ada")
      create(:donation, person:, fund:, amount_cents: 12_500, match_status: "auto")
      create(:donation, fund:, amount_cents: 1_000, status: "refunded")
      create(:donation, donor_name: "Unknown Giver")

      get giving_path
      expect(response.body).to include("$175.00", "General", "couldn't be matched")
      get donations_path(q: "Ada")
      expect(response.body).to include("$125.00")
      expect(response.body).not_to include("$10.00")
      get donations_path(format: :csv)
      expect(response.body.lines.first).to start_with("date,amount,currency,fund,person")
      get person_path(person)
      expect(response.body).to include("Giving", "$125.00")
    end

    it "matches, adds, and ignores gifts from the review queue" do
      gift = create(:donation, donor_name: "Grace Hopper", donor_email: "grace@example.com", donor_external_id: "d-9")
      hopper = create(:person, first_name: "Grace", last_name: "Hopper")
      get donation_matches_path
      expect(response.body).to include("Grace Hopper", "Likely matches", "Add as a new person")

      patch donation_match_path(gift), params: { person_id: hopper.id }
      expect(gift.reload).to have_attributes(person: hopper, match_status: "manual", matched_by: user)
      expect(DonorLink.find_by(donor_external_id: "d-9").person).to eq(hopper)

      newcomer = create(:donation, donor_name: "New Giver", donor_email: "new@example.com")
      post create_person_donation_match_path(newcomer)
      expect(newcomer.reload.person).to have_attributes(first_name: "New", last_name: "Giver", email: "new@example.com")

      other = create(:donation)
      patch ignore_donation_match_path(other)
      expect(other.reload).to be_match_ignored
    end

    it "shows one card per donor, and ignoring leaves all their gifts unmatched" do
      first = create(:donation, donor_external_id: "d-5", donor_name: "Repeat Giver", given_on: 2.weeks.ago.to_date, amount_cents: 2_000)
      create(:donation, donor_external_id: "d-5", donor_name: "Repeat Giver", given_on: 1.week.ago.to_date, amount_cents: 3_000)
      get donation_matches_path
      expect(response.body.scan("Repeat Giver").size).to eq(1)
      expect(response.body).to include("First of 2 gifts from this donor ($50.00 in all)")

      patch ignore_donation_match_path(first)
      expect(Donation.where(donor_external_id: "d-5").pluck(:match_status).uniq).to eq([ "ignored" ])
    end

    it "manages funds, keeping provider names" do
      post funds_path, params: { fund: { name: "Care fund", benevolence: "1" } }
      expect(Fund.find_by!(name: "Care fund")).to have_attributes(provider: "manual", benevolence: true)
      synced = create(:fund, name: "Missions", provider: "tithely", external_id: "f-2")
      patch fund_path(synced), params: { fund: { name: "Renamed", benevolence: "1" } }
      expect(synced.reload).to have_attributes(name: "Missions", benevolence: true)
    end

    it "shows the Tithe.ly connection as waiting on docs, and rejects its webhooks" do
      integration = create(:integration, category: "giving", provider: "tithely", credentials: { "api_key" => "k" }, settings: {})
      get giving_settings_path
      expect(response.body).to include("waiting on Tithe.ly", "/webhooks/#{integration.webhook_token}")
      post webhook_path(integration.webhook_token), params: "{}", headers: { "Content-Type" => "application/json" }
      expect(response).to have_http_status(:unauthorized)
      expect(WebhookEvent.count).to eq(0)
    end
  end

  it "keeps giving from staff by default" do
    sign_in_as(create(:user, :staff))
    get giving_path
    expect(response).to have_http_status(:forbidden)
    get donations_path
    expect(response).to have_http_status(:forbidden)
  end
end
