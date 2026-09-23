require "rails_helper"

# These stub the Graph API calls as the adapter makes them today. They prove the adapter
# does what we intended; the pending examples at the bottom must be verified against
# Meta's documentation before the adapter is trusted in production.
RSpec.describe Social::Providers::Meta do
  let(:graph) { "https://graph.facebook.com/v21.0" }
  let(:integration) { create(:integration, category: "social", provider: "meta", credentials: { "user_access_token" => "u" }, settings: {}) }
  let(:post) { create(:social_post, body: "Sunday at 10", link_url: "https://grace.example/visit") }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("META_APP_ID").and_return("app-1")
    allow(ENV).to receive(:[]).with("META_APP_SECRET").and_return("secret")
  end

  def target_for(account) = SocialPostTarget.find_by(social_post: post, social_account: account) || create(:social_post_target, social_post: post, social_account: account)

  it "builds the OAuth dialog link with the scopes it needs" do
    url = described_class.authorize_url(state: "abc", redirect_uri: "https://stewardly.app/oauth/meta/callback")
    expect(url).to start_with("https://www.facebook.com/v21.0/dialog/oauth?")
    expect(url).to include("client_id=app-1", "state=abc", "pages_manage_posts", "instagram_content_publish")
  end

  it "exchanges the code, gets a long-lived token, and lists Pages with their linked Instagram accounts" do
    stub_request(:get, %r{#{graph}/oauth/access_token.*code=c1}).to_return(body: { access_token: "short" }.to_json)
    stub_request(:get, %r{#{graph}/oauth/access_token.*fb_exchange_token=short}).to_return(body: { access_token: "long", expires_in: 5_184_000 }.to_json)
    stub_request(:get, %r{#{graph}/me\?}).to_return(body: { id: "m1", name: "Pastor" }.to_json)
    stub_request(:get, %r{#{graph}/me/accounts}).to_return(body: { data: [
      { id: "p1", name: "Grace", access_token: "page-tok", picture: { data: { url: "https://pic" } },
        instagram_business_account: { id: "ig1", username: "gracechurch", profile_picture_url: "https://igpic" } }
    ] }.to_json)

    token, expires_at, meta_user_id, accounts = described_class.connect(code: "c1", redirect_uri: "https://x/cb")
    expect([ token, meta_user_id ]).to eq([ "long", "m1" ])
    expect(expires_at).to be_within(1.minute).of(60.days.from_now)
    expect(accounts.map { |a| [ a.network, a.external_id, a.access_token ] }).to eq([ [ "facebook_page", "p1", "page-tok" ], [ "instagram", "ig1", "page-tok" ] ])
  end

  it "posts text with a link to a Page feed" do
    account = create(:social_account, integration:, external_id: "p1")
    feed = stub_request(:post, "#{graph}/p1/feed").with(body: hash_including("message" => "Sunday at 10", "link" => "https://grace.example/visit"))
      .to_return(body: { id: "p1_99" }.to_json)
    stub_request(:get, %r{#{graph}/p1_99\?}).to_return(body: { permalink_url: "https://facebook.com/p1_99" }.to_json)
    result = described_class.new(integration).publish(target_for(account), photo_urls: [])
    expect(feed).to have_been_requested
    expect(result.to_h).to eq(external_post_id: "p1_99", permalink: "https://facebook.com/p1_99")
  end

  it "posts to Instagram in two steps, with the link as text" do
    account = create(:social_account, :instagram, integration:, external_id: "ig1")
    create_media = stub_request(:post, "#{graph}/ig1/media").with(body: hash_including("image_url" => "https://site/p.png", "caption" => include("Link in bio")))
      .to_return(body: { id: "container-1" }.to_json)
    publish = stub_request(:post, "#{graph}/ig1/media_publish").with(body: hash_including("creation_id" => "container-1")).to_return(body: { id: "media-1" }.to_json)
    stub_request(:get, %r{#{graph}/media-1\?}).to_return(body: { permalink: "https://instagram.com/p/x" }.to_json)
    result = described_class.new(integration).publish(target_for(account), photo_urls: [ "https://site/p.png" ])
    expect([ create_media, publish ]).to all(have_been_requested)
    expect(result.external_post_id).to eq("media-1")
  end

  it "turns Graph errors into retry or reconnect signals" do
    account = create(:social_account, integration:, external_id: "p1")
    stub_request(:post, "#{graph}/p1/feed").to_return(status: 400, body: { error: { message: "Session has expired", code: 190 } }.to_json)
    expect { described_class.new(integration).publish(target_for(account), photo_urls: []) }
      .to raise_error(Social::Provider::Error) { |error| expect([ error.reconnect, error.transient ]).to eq([ true, false ]) }

    stub_request(:post, "#{graph}/p1/feed").to_return(status: 500, body: { error: { message: "Temporary", code: 2, is_transient: true } }.to_json)
    expect { described_class.new(integration).publish(target_for(account), photo_urls: []) }
      .to raise_error(Social::Provider::Error) { |error| expect(error.transient).to be(true) }
  end

  # TODO(verify vendor docs): check each against Meta's Graph API documentation for the pinned version.
  describe "against Meta's documentation" do
    before { pending "Verify against Meta's Graph API docs (#{described_class.version})" }

    it("OAuth dialog, code exchange, and long-lived token exchange") { raise "Check the parameters and responses" }
    it("/me/accounts fields, page tokens, and linked Instagram accounts") { raise "Check the fields and token lifetimes" }
    it("Page feed, single photo, and multi-photo (attached_media) posts") { raise "Check the endpoints and parameters" }
    it("Instagram containers, carousels, media_publish, and permalinks") { raise "Check the flow, including container status polling" }
    it("error codes, /debug_token, and signed_request callbacks") { raise "Check codes 190 and is_transient, and the callback formats" }
  end
end
