FactoryBot.define do
  factory :site do
    name { "Grace Community Church" }
  end

  factory :site_domain do
    site { Site.current }
    sequence(:hostname) { |n| "www.church#{n}.org" }

    trait :verified do
      status { "verified" }
      verified_at { Time.current }
    end
  end

  factory :page do
    site { Site.current }
    sequence(:title) { |n| "Page #{n}" }
    sequence(:slug) { |n| "page-#{n}" }
  end

  factory :page_revision do
    page
    published_at { Time.current }
  end
end
