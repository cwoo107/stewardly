require "rails_helper"

[ SocialAccount, SocialPost, SocialPostTarget ].each do |model|
  RSpec.describe model do
    it_behaves_like "a tenant-scoped model"
  end
end

RSpec.describe "Social tokens" do
  it "are never stored in plain text" do
    account = create(:social_account, access_token: "EAAB-secret-page-token")
    raw = SocialAccount.connection.select_value("SELECT access_token FROM social_accounts WHERE id = #{account.id}")
    expect(raw).not_to include("EAAB-secret")
    expect(account.reload.access_token).to eq("EAAB-secret-page-token")
  end
end
