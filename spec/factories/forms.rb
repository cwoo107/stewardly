FactoryBot.define do
  factory :form do
    sequence(:name) { |n| "Form #{n}" }

    trait :published do
      after(:create) do |form|
        form.fields.create!(label: "Name", field_type: "text") if form.fields.empty?
        form.publish!
      end
    end

    trait :prayer do
      purpose { "prayer_request" }
    end

    # A small published connect card: names, email, a checkbox, and a question shown only when it's ticked.
    trait :connect_card do
      after(:create) do |form|
        form.fields.create!(key: "first_name", label: "First name", field_type: "text", required: true, maps_to: "person.first_name")
        form.fields.create!(key: "last_name", label: "Last name", field_type: "text", required: true, maps_to: "person.last_name")
        form.fields.create!(key: "email", label: "Email", field_type: "email", maps_to: "person.email")
        form.fields.create!(key: "first_visit", label: "First visit", field_type: "checkbox")
        form.fields.create!(key: "heard", label: "How did you hear about us?", field_type: "select", options: [ "A friend", "Online" ],
          required: true, visibility_rule: { conditions: [ { field: "first_visit", operator: "filled" } ] })
        form.fields.reset
        form.publish!
      end
    end
  end

  factory :form_field do
    form
    sequence(:label) { |n| "Question #{n}" }
    field_type { "text" }
  end

  factory :form_submission do
    form
    answers { {} }
  end
end
