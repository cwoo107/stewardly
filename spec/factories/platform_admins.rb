FactoryBot.define do
  factory :platform_admin do
    name { "Pat Platform" }
    sequence(:email_address) { |n| "platform#{n}@stewardly.test" }
    password { "password" }
  end
end
