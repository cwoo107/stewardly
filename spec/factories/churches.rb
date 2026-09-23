FactoryBot.define do
  factory :church do
    sequence(:name) { |n| "Church #{n}" }
    sequence(:subdomain) { |n| "church#{n}" }
    time_zone { "Central Time (US & Canada)" }
  end
end
