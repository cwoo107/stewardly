FactoryBot.define do
  factory :role do
    sequence(:name) { |n| "Role #{n}" }
    sequence(:key) { |n| "role_#{n}" }
    permissions { [] }
  end
end
