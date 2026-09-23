require "rails_helper"

RSpec.describe Campaign do
  include ActiveJob::TestHelper

  let(:topic) { create(:email_topic) }
  let(:campaign) { create(:campaign, :ready, email_topic: topic) }

  it "lists what stops it sending" do
    draft = create(:campaign, email_template: nil, subject: "")
    expect(draft.problems).to include("Choose a template", "Add a subject", a_string_including("postal address"))
    expect(campaign.problems).to be_empty
  end

  describe "audience" do
    let!(:plain) { create(:person) }
    let!(:no_email) { create(:person, email: nil) }
    let!(:bounced) { create(:person).tap { |p| Suppression.record!(p.email, reason: :hard_bounce) } }
    let!(:unsubscribed_topic) { create(:person).tap { |p| Suppression.record!(p.email, reason: :unsubscribed, topic:) } }
    let!(:unsubscribed_other) { create(:person).tap { |p| Suppression.record!(p.email, reason: :unsubscribed, topic: create(:email_topic)) } }
    let!(:opted_out) { create(:person).tap { |p| create(:email_preference, person: p, email_topic: topic, subscribed: false) } }

    it "is the segment's people with email, minus suppressions and opt-outs" do
      expect(campaign.audience.people).to contain_exactly(plain, unsubscribed_other)
    end

    it "only includes people who opted in to an opt-in topic" do
      topic.update!(default_subscribed: false)
      create(:email_preference, person: plain, email_topic: topic, subscribed: true)
      expect(campaign.audience.people).to contain_exactly(plain)
    end
  end

  describe "sending" do
    let!(:people) { create_list(:person, 3) }

    it "creates one delivery per person, sends each once, and marks the campaign sent" do
      perform_enqueued_jobs { campaign.send_now! }

      expect(campaign.reload).to be_sent
      expect(campaign.deliveries.pluck(:status).uniq).to eq([ "sent" ])
      expect(ActionMailer::Base.deliveries.map(&:to).flatten).to match_array(people.map(&:email))

      mail = ActionMailer::Base.deliveries.find { |m| m.to == [ people.first.email ] }
      delivery = campaign.deliveries.find_by(person: people.first)
      expect(mail.subject).to eq("Hello #{people.first.first_name}")
      expect(mail["List-Unsubscribe"].value).to include("/u/#{delivery.token}")
      expect(mail["List-Unsubscribe-Post"].value).to eq("List-Unsubscribe=One-Click")
      expect(mail.html_part.decoded).to include("/t/o/#{delivery.token}.gif")
      expect(people.first.touchpoints.email.last.subject).to eq(campaign)
    end

    it "never sends twice when dispatch or batches run again" do
      perform_enqueued_jobs { campaign.send_now! }
      Campaign::Dispatch.new(campaign.reload).dispatch!
      DeliveryBatchJob.perform_now(campaign, campaign.deliveries.ids)
      expect(ActionMailer::Base.deliveries.size).to eq(3)
      expect(campaign.deliveries.count).to eq(3)
    end

    it "skips people suppressed after the campaign started" do
      campaign.schedule!(Time.current)
      Campaign::Dispatch.new(campaign).dispatch!
      Suppression.record!(people.first.email, reason: :complaint)
      perform_enqueued_jobs(only: DeliveryBatchJob)
      expect(campaign.deliveries.find_by(person: people.first)).to be_skipped
      expect(ActionMailer::Base.deliveries.size).to eq(2)
    end

    it "starts scheduled campaigns when they're due" do
      campaign.schedule!(1.hour.from_now)
      CampaignSchedulerJob.perform_now
      expect(enqueued_jobs.map { |job| job["job_class"] }).not_to include("CampaignDispatchJob")
      travel(2.hours) { CampaignSchedulerJob.perform_now }
      expect(enqueued_jobs.map { |job| job["job_class"] }).to include("CampaignDispatchJob")
    end

    it "sends through the church's provider when one is connected" do
      create(:integration)
      stub = stub_request(:post, "https://api.postmarkapp.com/email")
        .to_return(status: 200, headers: { "Content-Type" => "application/json" },
          body: { "ErrorCode" => 0, "Message" => "OK", "MessageID" => "pm-1", "To" => "x" }.to_json)
      perform_enqueued_jobs { campaign.send_now! }
      expect(stub).to have_been_requested.times(3)
      expect(campaign.deliveries.pluck(:provider_message_id).uniq).to eq([ "pm-1" ])
      expect(a_request(:post, "https://api.postmarkapp.com/email").with { |req| JSON.parse(req.body)["MessageStream"] == "broadcast" }).to have_been_made.times(3)
    end
  end
end
