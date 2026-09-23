FactoryBot.define do
  factory :fund do
    sequence(:name) { |n| "Fund #{n}" }
    provider { "manual" }

    trait :benevolence do
      benevolence { true }
    end
  end

  factory :donation do
    provider { "tithely" }
    sequence(:external_id) { |n| "gift-#{n}" }
    amount_cents { 5_000 }
    given_on { Date.current }
    fund
  end

  factory :donor_link do
    person
    provider { "tithely" }
    sequence(:donor_external_id) { |n| "donor-#{n}" }
  end

  factory :giving_sync_run do
    integration { association :integration, category: "giving", provider: "tithely", credentials: { "api_key" => "k" }, settings: {} }
    kind { "reconcile" }
  end

  factory :benevolence_case do
    person
    summary { "Help with rent" }
    need_category { "rent" }
    requested_cents { 30_000 }
  end

  factory :benevolence_note do
    benevolence_case
    body { "Called them back" }
  end

  factory :benevolence_approval do
    benevolence_case
    user
    decision { "approve" }
    amount_cents { 30_000 }
  end

  factory :benevolence_disbursement do
    benevolence_case { association :benevolence_case, status: "approved", approved_cents: 30_000 }
    amount_cents { 10_000 }
    paid_on { Date.current }
    add_attribute(:method) { "check" }
    payee_type { "landlord" }
    payee_name { "Springfield Apartments" }
  end
end
