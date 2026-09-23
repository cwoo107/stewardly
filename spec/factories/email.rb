FactoryBot.define do
  factory :email_topic do
    sequence(:name) { |n| "Topic #{n}" }
    default_subscribed { true }
  end

  factory :email_preference do
    person
    email_topic
    subscribed { false }
  end

  factory :email_template do
    sequence(:name) { |n| "Template #{n}" }
    subject { "News from church" }
  end

  factory :section_definition do
    sequence(:key) { |n| "custom_#{n}" }
    name { "Custom" }
    liquid { "<mj-section><mj-column><mj-text>{{ settings.title }}</mj-text></mj-column></mj-section>" }
    schema { { "settings" => [ { "id" => "title", "type" => "text", "label" => "Title" } ] } }
  end

  factory :campaign do
    sequence(:name) { |n| "Campaign #{n}" }
    subject { "Hello {{ person.first_name }}" }
    email_template
    segment
    email_topic

    trait :ready do
      after(:build) { |campaign| campaign.church.update!(mailing_address: "1 Church St, Springfield") }
    end
  end

  factory :delivery do
    campaign
    person
    email { person.email }
  end

  factory :suppression do
    sequence(:email) { |n| "suppressed#{n}@example.com" }
    reason { :manual }
  end

  factory :integration do
    category { "email_delivery" }
    provider { "postmark" }
    credentials { { "server_token" => "server-token-123", "webhook_password" => "hook-secret" } }
    settings { { "broadcast_stream" => "broadcast" } }
  end

  factory :webhook_event do
    integration
    provider { integration.provider }
    raw_body { { "RecordType" => "Delivery" }.to_json }
  end
end
