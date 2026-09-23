FactoryBot.define do
  factory :tag do
    sequence(:name) { |n| "Tag #{n}" }
    color { "cyan" }
  end

  factory :tagging do
    tag
    person
  end

  factory :custom_field do
    sequence(:label) { |n| "Field #{n}" }
    field_type { "text" }

    trait :select do
      field_type { "select" }
      options { %w[ S M L ] }
    end
  end

  factory :touchpoint do
    person
    kind { "note" }
    summary { "Had coffee" }
    occurred_at { 1.day.ago }
  end

  factory :person_import do
    transient do
      csv { "First name,Last name,Email\nAda,Lovelace,ada@example.com\n" }
    end

    file { Rack::Test::UploadedFile.new(StringIO.new(csv), "text/csv", original_filename: "people.csv") }
  end

  factory :segment do
    sequence(:name) { |n| "Segment #{n}" }
    definition { { match: "all", conditions: [] } }
  end

  factory :campus do
    sequence(:name) { |n| "Campus #{n}" }

    trait :with_location do
      transient do
        latitude { 36.1627 }
        longitude { -86.7816 }
      end

      location { Campus.point(latitude:, longitude:) }
    end
  end

  factory :duplicate_dismissal do
    person
    other_person factory: :person
  end

  factory :ministry do
    sequence(:name) { |n| "Ministry #{n}" }
  end

  factory :ministry_leadership do
    ministry
    user
  end

  factory :group do
    sequence(:name) { |n| "Group #{n}" }
    group_type { "small_group" }

    trait :with_location do
      transient do
        latitude { 36.1627 }
        longitude { -86.7816 }
      end

      location { Group.point(latitude:, longitude:) }
    end
  end

  factory :group_membership do
    group
    person
  end

  factory :team do
    ministry
    sequence(:name) { |n| "Team #{n}" }
  end

  factory :position do
    team
    sequence(:name) { |n| "Position #{n}" }
  end

  factory :team_membership do
    team
    person
  end

  factory :project do
    sequence(:name) { |n| "Project #{n}" }
  end

  factory :task do
    sequence(:title) { |n| "Task #{n}" }
    status { "todo" }
  end

  factory :prayer_request do
    person
    body { "Please pray for my family" }
    visibility { "prayer_team" }
  end

  factory :prayer_assignment do
    prayer_request
    user
  end
end
