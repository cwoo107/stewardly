FactoryBot.define do
  factory :social_account do
    integration { Integration.find_by(category: "social") || association(:integration, category: "social", provider: "meta", credentials: { "user_access_token" => "user-token" }, settings: { "meta_user_id" => "meta-user-1" }) }
    network { "facebook_page" }
    sequence(:external_id) { |n| "page-#{n}" }
    name { "Grace Community Church" }
    access_token { "page-token" }

    trait :instagram do
      network { "instagram" }
      handle { "gracechurch" }
    end
  end

  factory :social_post do
    body { "Join us this Sunday!" }

    transient do
      accounts { [] }
    end

    after(:build) { |post, context| post.account_ids = context.accounts.map(&:id) if context.accounts.any? }
  end

  factory :social_post_target do
    social_post
    social_account
  end
end
