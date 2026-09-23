FactoryBot.define do
  factory :worship_service do
    sequence(:name) { |n| "Service #{n}" }
    day_of_week { 0 }
    start_time { "09:00" }
    duration_minutes { 75 }
  end

  factory :service_occurrence do
    worship_service
    local_date { Date.current.next_occurring(:sunday) }
    starts_at { worship_service.times_on(local_date).first }
    ends_at { worship_service.times_on(local_date).last }
  end

  factory :position_need do
    needable factory: :worship_service
    position
    quantity { 1 }
  end

  factory :assignment do
    schedulable factory: :service_occurrence
    position
    person
  end

  factory :position_qualification do
    position
    person
    after(:build) { |q| q.position.team.team_memberships.find_or_create_by!(person: q.person) }
  end

  factory :blockout do
    person
    starts_on { Date.current + 7 }
    ends_on { starts_on }
  end

  factory :event do
    sequence(:title) { |n| "Event #{n}" }
    status { "published" }
    visibility { "public" }

    trait :registration do
      registration_required { true }
    end
  end

  factory :event_occurrence do
    event
    starts_at { 3.days.from_now.change(hour: 18) }
    ends_at { starts_at + 2.hours }
  end

  factory :registration do
    event_occurrence
    person
  end

  factory :course do
    sequence(:name) { |n| "Course #{n}" }
  end

  factory :course_offering do
    course
    starts_on { Date.current + 7 }
  end

  factory :course_session do
    course_offering
    starts_at { 8.days.from_now.change(hour: 12) }
    ends_at { starts_at + 75.minutes }
  end

  factory :enrollment do
    course_offering
    person
  end

  factory :session_attendance do
    course_session
    enrollment { association :enrollment, course_offering: course_session.course_offering }
  end

  factory :announcement do
    sequence(:title) { |n| "Update #{n}" }
    body { "Something happening at church" }
    published_at { 1.hour.ago }
  end

  factory :group_join_request do
    group
    person
  end
end
