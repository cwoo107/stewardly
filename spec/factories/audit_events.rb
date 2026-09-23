FactoryBot.define do
  factory :audit_event do
    action { "user.deleted" }
    auditable factory: :user
    metadata { {} }
  end
end
