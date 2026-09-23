FactoryBot.define do
  factory :attendance_count do
    service_occurrence
    total { 200 }
  end

  factory :attendance do
    service_occurrence
    person
  end

  factory :special_sunday do
    sequence(:local_date) { |n| Date.new(2026, 1, 4) + (n * 7) }
    name { "Friend day" }
  end

  factory :attendance_forecast do
    service_occurrence
    expected { 200 }
    low { 180 }
    high { 220 }
    model_version { AttendanceForecast::MODEL_VERSION }
    generated_at { Time.current }
  end
end
