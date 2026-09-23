require "rails_helper"

RSpec.describe Email::EventProcessing do
  let(:integration) { create(:integration) }
  let(:delivery) { create(:delivery, status: :sent, provider_message_id: "m-1") }

  # Events are built directly so this spec doesn't depend on unverified vendor payloads.
  def process(*events)
    webhook = create(:webhook_event, integration:)
    allow_any_instance_of(Email::Providers::Postmark).to receive(:events_from).and_return(events)
    described_class.new(webhook).process!
    webhook.reload
  end

  def event(type, hard: false) = Email::DeliveryProvider::Event.new(type, "m-1", delivery.email, hard, Time.current, nil)

  it "marks deliveries delivered" do
    expect(process(event("delivered"))).to be_processed
    expect(delivery.reload).to be_delivered
  end

  it "suppresses hard bounces and complaints, not soft bounces, and is safe to replay" do
    process(event("bounced", hard: false))
    expect(Suppression.exists?(email: delivery.email)).to be(false)
    2.times { process(event("complained")) }
    expect(delivery.reload).to be_complained
    expect(Suppression.where(email: delivery.email, reason: "complaint").count).to eq(1)
  end
end
