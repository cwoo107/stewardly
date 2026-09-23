require "rails_helper"

RSpec.describe Suppression do
  let(:topic) { create(:email_topic) }
  let(:other_topic) { create(:email_topic) }

  it "blocks all mail for bounces, complaints, and topic-less manual entries" do
    described_class.record!("Bounced@Example.com", reason: :hard_bounce)
    create(:suppression, email: "manual@example.com")
    expect(described_class.blocks?("bounced@example.com", topic: :system)).to be(true)
    expect(described_class.blocks?("manual@example.com", topic: :system)).to be(true)
  end

  it "only stops campaigns for unsubscribes, and topic unsubscribes only stop that topic" do
    described_class.record!("all@example.com", reason: :unsubscribed)
    described_class.record!("one@example.com", reason: :unsubscribed, topic:)
    expect(described_class.blocks?("all@example.com", topic: :system)).to be(false)
    expect(described_class.blocks?("all@example.com", topic:)).to be(true)
    expect(described_class.blocks?("one@example.com", topic:)).to be(true)
    expect(described_class.blocks?("one@example.com", topic: other_topic)).to be(false)
  end

  it "records each address once per topic" do
    2.times { described_class.record!("twice@example.com", reason: :complaint) }
    expect(described_class.where(email: "twice@example.com").count).to eq(1)
  end
end
