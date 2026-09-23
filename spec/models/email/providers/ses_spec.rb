require "rails_helper"

RSpec.describe Email::Providers::Ses do
  let(:integration) { create(:integration, provider: "ses", credentials: { "access_key_id" => "AKIA", "secret_access_key" => "s" }, settings: { "region" => "us-east-1" }) }

  it "rejects webhooks that SNS didn't sign" do
    request = ActionDispatch::TestRequest.create("RAW_POST_DATA" => { "Type" => "Notification", "Message" => "{}" }.to_json)
    expect { described_class.new(integration).verify_webhook!(request) }.to raise_error(Email::DeliveryProvider::InvalidWebhook)
  end

  # TODO(verify vendor docs): replace with samples from the SES event publishing and SNS
  # docs (Bounce Permanent, Complaint, Delivery, SubscriptionConfirmation).
  describe "SNS notifications" do
    before { pending "Verify against the SES/SNS docs" }

    it "reads a permanent bounce" do
      raise "Paste a real SES Bounce notification (inside an SNS envelope) here and assert on events_from"
    end
  end
end
