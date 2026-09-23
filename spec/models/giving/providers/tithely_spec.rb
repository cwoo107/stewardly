require "rails_helper"

RSpec.describe Giving::Providers::Tithely do
  let(:integration) { create(:integration, category: "giving", provider: "tithely", credentials: { "api_key" => "k" }, settings: {}) }

  it "refuses to sync or accept webhooks until it's written against Tithe.ly's docs" do
    adapter = described_class.new(integration)
    expect { adapter.funds }.to raise_error(Giving::Provider::Error, /documentation/)
    expect { adapter.verify_webhook!(ActionDispatch::TestRequest.create) }.to raise_error(Giving::Provider::InvalidWebhook)
  end

  # TODO(verify vendor docs): replace with stubbed requests and real sample payloads from Tithe.ly's API docs.
  describe "against Tithe.ly's API" do
    before { pending "Needs Tithe.ly's API documentation" }

    it("lists funds") { raise "Stub Tithe.ly's funds endpoint and assert FundRecords" }
    it("pages through transactions in a date range, including refunds") { raise "Stub the transactions endpoint and assert DonationRecords" }
    it("verifies webhook signatures and reads donations from them") { raise "Use a signed sample webhook" }
  end
end
