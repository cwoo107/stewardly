require "rails_helper"

RSpec.describe "Email" do
  include ActiveJob::TestHelper

  before { church.update!(mailing_address: "1 Church St") }

  context "as staff" do
    before { sign_in_as(create(:user, :staff)) }

    it "builds a template from sections and previews it" do
      get new_email_template_path
      expect(response.body).to include("email_template[theme][brand_color]")
      post email_templates_path, params: { email_template: { name: "Weekly", subject: "This week", theme: { brand_color: "#112233" } } }
      template = EmailTemplate.find_by!(name: "Weekly")
      expect(template.theme_settings["brand_color"]).to eq("#112233")

      post email_template_sections_path(template), params: { key: "links" }
      section = template.reload.sections.last
      patch email_template_section_path(template, section["id"]), params: { settings: { heading: "Find us", blocks: { "0" => { label: "Site", url: "https://grace.example" } } }, block_action: "add" }
      expect(response).to redirect_to(edit_email_template_section_path(template, section["id"]))
      expect(template.reload.sections.last.dig("settings", "blocks").size).to eq(2)

      get email_template_path(template)
      expect(response.body).to include("Links", "Add a section")
      get preview_email_template_path(template, width: "mobile")
      expect(response.body).to include("srcdoc=", "Find us", "width: 375px")
    end

    it "uploads an image, sizes it, and shows it in the preview" do
      template = create(:email_template)
      post email_template_sections_path(template), params: { key: "image" }
      section = template.reload.sections.last
      patch email_template_section_path(template, section["id"]), params: { settings: {
        image_url: fixture_file_upload("landscape.png", "image/png"), width: "300", height: "120", fit: "crop", align: "left" } }

      settings = template.reload.sections.last["settings"]
      expect(settings).to include("image_url" => a_string_starting_with("/rails/active_storage/blobs/"), "width" => 300, "height" => 120, "fit" => "crop")

      get edit_email_template_section_path(template, section["id"])
      expect(response.body).to include("landscape.png", "Remove image", "Best fit", "Crop")

      get preview_email_template_path(template)
      srcdoc = CGI.unescapeHTML(Nokogiri::HTML(response.body).at_css("iframe")["srcdoc"])
      image = Nokogiri::HTML(srcdoc).css("img").find { |img| img["src"].include?("/representations/") }
      expect(image["src"]).to start_with("http://#{church.host}/rails/active_storage/representations/")
      expect(image["width"]).to eq("300")
      expect(image["height"]).to eq("120")

      patch email_template_section_path(template, section["id"]), params: { settings: { image_url_keep: settings["image_url"], width: "", height: "" } }
      expect(template.reload.sections.last.dig("settings", "image_url")).to eq(settings["image_url"])
      patch email_template_section_path(template, section["id"]), params: { settings: { image_url_keep: settings["image_url"], image_url_remove: "1" } }
      expect(template.reload.sections.last.dig("settings", "image_url")).to be_nil
    end

    it "sends a test email" do
      template = create(:email_template)
      expect { post test_email_template_path(template) }.to have_enqueued_mail(CampaignMailer, :test)
    end

    it "creates, reviews, and sends a campaign, then shows the report" do
      create_list(:person, 2)
      template = create(:email_template)
      post campaigns_path, params: { campaign: { name: "Sept news", email_template_id: template.id, segment_id: create(:segment).id, email_topic_id: EmailTopic.default!.id } }
      campaign = Campaign.find_by!(name: "Sept news")
      expect(campaign.subject).to eq(template.subject)

      get campaign_path(campaign)
      expect(response.body).to include("Send now to 3 people") # two people plus the staff user's own person

      perform_enqueued_jobs { patch deliver_campaign_path(campaign) }
      expect(campaign.reload).to be_sent
      get campaign_path(campaign)
      expect(response.body).to include("Delivered", "Unsubscribed", campaign.deliveries.first.email)
    end

    it "won't send without a postal address" do
      church.update!(mailing_address: nil)
      campaign = create(:campaign)
      patch deliver_campaign_path(campaign)
      expect(flash[:alert]).to include("postal address")
      expect(campaign.reload).to be_draft
    end

    it "manages topics and suppressions" do
      post email_topics_path, params: { email_topic: { name: "Kids", default_subscribed: "0" } }
      expect(EmailTopic.find_by!(name: "Kids").default_subscribed).to be(false)
      post suppressions_path, params: { suppression: { email: "Nope@Example.com" } }
      expect(Suppression.find_by!(email: "nope@example.com")).to be_manual
      get suppressions_path(q: "nope")
      expect(response.body).to include("nope@example.com")
    end

    it "saves the postal address but can't see provider credentials" do
      patch email_settings_path, params: { church: { mailing_address: "2 Hill Rd", email_from_domain: "grace.org" } }
      expect(church.reload.email_from_address).to eq("hello@grace.org")
      post integrations_path, params: { integration: { category: "email_delivery", provider: "postmark" } }
      expect(response).to have_http_status(:forbidden)
      get webhook_events_path
      expect(response).to have_http_status(:forbidden)
    end
  end

  context "as a church admin" do
    before { sign_in_as(create(:user, :church_admin)) }

    it "connects a provider without ever showing the saved credentials" do
      post integrations_path, params: { integration: { category: "email_delivery", provider: "postmark",
        credentials: { server_token: "tok-123", webhook_password: "pw" }, settings: { broadcast_stream: "news" } } }
      integration = Integration.last
      expect(integration.credential(:server_token)).to eq("tok-123")

      patch integration_path(integration), params: { integration: { credentials: { server_token: "" }, settings: { broadcast_stream: "news" } } }
      expect(integration.reload.credential(:server_token)).to eq("tok-123")

      get email_settings_path
      expect(response.body).to include("Postmark connected", "/webhooks/#{integration.webhook_token}", "Saved (leave blank to keep)")
      expect(response.body).not_to include("tok-123")
    end

    it "replays a stored webhook" do
      event = create(:webhook_event, integration: create(:integration))
      expect { post replay_webhook_event_path(event) }.to have_enqueued_job(IntegrationWebhookJob).with(event)
    end
  end

  it "keeps email pages from members" do
    sign_in_as(create(:user, :member))
    get campaigns_path
    expect(response).to have_http_status(:forbidden)
  end

  describe "public endpoints" do
    before { on_church(church) }

    let!(:topic) { EmailTopic.default! }
    let(:delivery) { create(:delivery, campaign: create(:campaign, email_topic: topic)) }

    it "asks before unsubscribing, then unsubscribes from the topic" do
      get unsubscribe_path(delivery.token)
      expect(response.body).to include("Unsubscribe #{delivery.email}?")
      expect(Suppression.count).to eq(0)

      post unsubscribe_path(delivery.token)
      expect(Suppression.find_by!(email: delivery.email)).to have_attributes(reason: "unsubscribed", email_topic_id: topic.id)
      expect(delivery.reload.unsubscribed_at).to be_present
    end

    it "handles one-click unsubscribes from mail apps without a CSRF token" do
      ActionController::Base.allow_forgery_protection = true
      post unsubscribe_path(delivery.token), params: { "List-Unsubscribe" => "One-Click" }
      expect(response).to have_http_status(:ok)
      expect(Suppression.exists?(email: delivery.email)).to be(true)
    ensure
      ActionController::Base.allow_forgery_protection = false
    end

    it "lets people choose topics with a signed link" do
      kids = create(:email_topic, name: "Kids")
      token = delivery.person.generate_token_for(:email_preferences)
      get email_preferences_path(token)
      expect(response.body).to include("Kids", topic.name)

      patch email_preferences_path(token), params: { topic_ids: [ kids.id ] }
      expect(topic.subscribed?(delivery.person.reload)).to be(false)
      expect(kids.subscribed?(delivery.person)).to be(true)

      get email_preferences_path("forged")
      expect(response).to have_http_status(:not_found)
    end

    it "tracks opens and clicks, redirecting only to signed URLs" do
      get email_open_path(delivery.token, format: :gif)
      expect(response.media_type).to eq("image/gif")
      expect(delivery.reload.open_count).to eq(1)

      get email_click_path(delivery.token, Email::Tracking.sign("https://grace.example/give"))
      expect(response).to redirect_to("https://grace.example/give")
      expect(delivery.reload.click_count).to eq(1)

      get email_click_path(delivery.token, "tampered")
      expect(response).to have_http_status(:not_found)
    end

    it "stores verified webhooks raw and processes them in a job" do
      integration = create(:integration)
      auth = ActionController::HttpAuthentication::Basic.encode_credentials("postmark", "hook-secret")
      body = { "RecordType" => "Delivery", "MessageID" => "m-1" }.to_json

      expect {
        post webhook_path(integration.webhook_token), params: body, headers: { "Authorization" => auth, "Content-Type" => "application/json" }
      }.to have_enqueued_job(IntegrationWebhookJob)
      expect(WebhookEvent.last.raw_body).to eq(body)

      post webhook_path(integration.webhook_token), params: body, headers: { "Content-Type" => "application/json" }
      expect(response).to have_http_status(:unauthorized)
      post webhook_path("unknown"), params: body
      expect(response).to have_http_status(:not_found)
    end
  end
end
