require "rails_helper"

RSpec.describe "Social media" do
  include ActiveJob::TestHelper

  let!(:facebook) { create(:social_account, name: "Grace Community Church") }
  let!(:instagram) { create(:social_account, :instagram) }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("META_APP_ID").and_return("app-1")
    allow(ENV).to receive(:[]).with("META_APP_SECRET").and_return("app-secret")
  end

  context "as staff" do
    before { sign_in_as(create(:user, :staff)) }

    it "composes with a photo and a per-network caption, previews, schedules, and the sweep publishes it" do
      post social_posts_path, params: { social_post: { body: "Fall Festival this Saturday!", link_url: "https://grace.example/fall",
        account_ids: [ facebook.id, instagram.id ], captions: { instagram.id => "Fall Festival 🍂 Saturday!" },
        media: [ fixture_file_upload("landscape.png", "image/png") ] } }
      social_post = SocialPost.last
      expect(social_post.targets.find_by(social_account: instagram).caption).to eq("Fall Festival 🍂 Saturday!")
      expect(social_post.media.count).to eq(1)

      get edit_social_post_path(social_post)
      expect(response.body).to include("Fall Festival 🍂 Saturday!", "Link in bio: https://grace.example/fall", "Schedule for")

      patch schedule_social_post_path(social_post), params: { scheduled_at: 2.hours.from_now.in_time_zone(church.zone).strftime("%Y-%m-%dT%H:%M") }
      expect(social_post.reload).to be_scheduled

      allow_any_instance_of(Social::Providers::Meta).to receive(:publish).and_return(Social::Provider::PublishResult.new("x1", "https://facebook.com/x1"))
      perform_enqueued_jobs { SocialPublishSweepJob.perform_now }
      expect(social_post.reload).to be_scheduled # not due yet
      travel(3.hours) { perform_enqueued_jobs { SocialPublishSweepJob.perform_now } }
      expect(social_post.reload).to be_published
      get social_post_path(social_post)
      expect(response.body).to include("See it on Facebook", "See it on Instagram")
    end

    it "won't schedule a post that breaks a network's rules" do
      social_post = create(:social_post, accounts: [ instagram ])
      patch schedule_social_post_path(social_post), params: { scheduled_at: 1.day.from_now.strftime("%Y-%m-%dT%H:%M") }
      expect(flash[:alert]).to include("needs a photo")
      expect(social_post.reload).to be_draft
    end

    it "retries a failed target or marks it posted after checking" do
      social_post = create(:social_post, accounts: [ facebook ], status: "failed")
      target = social_post.targets.first
      target.update!(status: "unknown")
      patch mark_posted_social_post_target_path(social_post, target), params: { permalink: "https://facebook.com/p/1" }
      expect(target.reload).to have_attributes(status: "published", permalink: "https://facebook.com/p/1")
      expect(social_post.reload).to be_published
    end

    it "shows scheduled posts and un-promoted events on the calendar, and drafts a promo from it" do
      create(:social_post, accounts: [ facebook ], status: "scheduled", scheduled_at: church.now.end_of_month - 1.day, body: "Save the date")
      event = create(:event, title: "Baptism Sunday")
      create(:event_occurrence, event:, starts_at: church.now.change(day: [ church.today.day, 25 ].max) + 1.hour)
      get social_calendar_path(month: church.today.strftime("%Y-%m"))
      expect(response.body).to include("Save the date", "Baptism Sunday", "Draft a promo")
      get new_social_post_path(event_id: event.id)
      expect(SocialPost.last).to have_attributes(event:, source: "event_promo", status: "draft")
    end

    it "can see accounts but not connect them" do
      get social_accounts_path
      expect(response.body).to include("Instagram: @gracechurch")
      get connect_social_accounts_path
      expect(response).to have_http_status(:forbidden)
    end
  end

  context "connecting (church admin)" do
    let(:admin) { create(:user, :church_admin) }

    before { sign_in_as(admin) }

    it "goes to Meta with a signed state, and the platform callback saves the accounts and returns to the church" do
      get connect_social_accounts_path
      expect(response.location).to start_with("https://www.facebook.com/v21.0/dialog/oauth")
      state = Rack::Utils.parse_query(URI(response.location).query)["state"]

      graph = "https://graph.facebook.com/v21.0"
      stub_request(:get, %r{#{graph}/oauth/access_token.*code=abc}).to_return(body: { access_token: "short" }.to_json)
      stub_request(:get, %r{#{graph}/oauth/access_token.*fb_exchange_token}).to_return(body: { access_token: "long", expires_in: 100 }.to_json)
      stub_request(:get, %r{#{graph}/me\?}).to_return(body: { id: "meta-9" }.to_json)
      stub_request(:get, %r{#{graph}/me/accounts}).to_return(body: { data: [ { id: "p9", name: "Grace Youth", access_token: "t9" } ] }.to_json)

      on_platform
      get meta_oauth_callback_path(code: "abc", state:)
      expect(response.location).to eq("http://#{church.host}/social/accounts?connected=1")
      expect(SocialAccount.find_by!(external_id: "p9")).to have_attributes(name: "Grace Youth", access_token: "t9")
      expect(AuditEvent.last).to have_attributes(action: "social.connected", actor: admin)

      get meta_oauth_callback_path(code: "abc", state: "forged")
      expect(response).to have_http_status(:bad_request)
    end

    it "disconnects when Meta sends a verified deauthorize or data deletion request" do
      integration = facebook.integration
      encode = ->(value) { Base64.urlsafe_encode64(value, padding: false) }
      payload = encode.({ user_id: "meta-user-1", algorithm: "HMAC-SHA256" }.to_json)
      signed = "#{encode.(OpenSSL::HMAC.digest("SHA256", "app-secret", payload))}.#{payload}"

      on_platform
      post "/oauth/meta/deauthorize", params: { signed_request: "bad.#{payload}" }
      expect(response).to have_http_status(:bad_request)
      post "/oauth/meta/data_deletion", params: { signed_request: signed }
      expect(response.parsed_body).to include("url", "confirmation_code")
      expect(facebook.reload).to have_attributes(status: "disconnected", access_token: nil)
      expect(integration.reload).to be_disabled
    end
  end

  it "keeps social from members" do
    sign_in_as(create(:user, :member))
    get social_posts_path
    expect(response).to have_http_status(:forbidden)
  end
end
