FactoryBot.define do
  factory :person do
    first_name { "Jordan" }
    sequence(:last_name) { |n| "Person#{n}" }
    sequence(:email) { |n| "person#{n}@example.com" }
  end
end
