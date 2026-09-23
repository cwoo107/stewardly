require "rails_helper"

RSpec.describe Integration do
  it "encrypts credentials, so they're never stored in plain text" do
    integration = create(:integration)
    raw = described_class.connection.select_value("SELECT credentials FROM integrations WHERE id = #{integration.id}")
    expect(raw).not_to include("server-token-123")
    expect(integration.reload.credential(:server_token)).to eq("server-token-123")
  end

  it "allows one active provider per category and checks the provider fits" do
    create(:integration)
    expect(build(:integration, provider: "ses")).not_to be_valid
    expect(build(:integration, category: "email_audience_sync", provider: "postmark")).not_to be_valid
  end
end
