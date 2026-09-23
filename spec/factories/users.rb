FactoryBot.define do
  factory :user do
    person
    email_address { person.email }
    password { "password" }

    # Grants the church's role with this key, creating it when the church doesn't have it yet.
    transient do
      role_keys { [] }
    end

    after(:build) do |user, context|
      context.role_keys.each do |key|
        attributes = Role::DEFAULTS.find { |role| role[:key] == key.to_s } || { key: key.to_s, name: key.to_s.humanize }
        user.roles << (Role.find_by(key: key.to_s) || Role.create!(attributes))
      end
    end

    trait(:church_admin) { role_keys { [ :church_admin ] } }
    trait(:staff) { role_keys { [ :staff ] } }
    trait(:care_team) { role_keys { [ :care_team ] } }
    trait(:member) { role_keys { [ :member ] } }
  end
end
