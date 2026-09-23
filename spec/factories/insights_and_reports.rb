FactoryBot.define do
  factory :insight do
    kind { "overdue_task" }
    title { "Something needs attention" }
    severity { "medium" }
    audience_permission { "manage_tasks" }
    sequence(:fingerprint) { |n| "test:#{n}" }
    detected_at { Time.current }
    last_seen_at { Time.current }
  end

  factory :daily_brief do
    user
    date { Date.current }
  end

  factory :report_conversation do
    user
    title { "How are we doing?" }
  end

  factory :report_message do
    report_conversation
    role { "user" }
    content { "How are we doing?" }
  end

  factory :saved_report do
    user
    title { "People" }
    tool_calls { [ { "name" => "people_counts", "arguments" => {} } ] }
  end
end
