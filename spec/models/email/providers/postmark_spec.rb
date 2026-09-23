require "rails_helper"

RSpec.describe Email::Providers::Postmark do
  let(:integration) { create(:integration) }

  it "rejects webhooks without the right basic-auth password" do
    adapter = described_class.new(integration)
    good = ActionDispatch::TestRequest.create("HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("postmark", "hook-secret"))
    bad = ActionDispatch::TestRequest.create("HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("postmark", "nope"))
    expect { adapter.verify_webhook!(good) }.not_to raise_error
    expect { adapter.verify_webhook!(bad) }.to raise_error(Email::DeliveryProvider::InvalidWebhook)
  end

  # TODO(verify vendor docs): replace these payloads with samples from Postmark's webhook
  # documentation (Delivery, Bounce with Type HardBounce, SpamComplaint, SubscriptionChange).
  describe "webhook payloads" do
    before { pending "Verify against Postmark's webhook docs" }

    it "reads a hard bounce" do
      raise "Paste a real Postmark Bounce webhook sample here and assert on events_from"
    end
  end
end
