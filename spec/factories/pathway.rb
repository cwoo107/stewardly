FactoryBot.define do
  factory :pathway do
    name { "Connect, Grow, Serve" }
  end

  factory :pathway_stage do
    pathway { Pathway.first || association(:pathway) }
    sequence(:name) { |n| "Stage #{n}" }
  end

  factory :pathway_placement do
    person
    pathway_stage
    entered_at { Time.current }
    evaluated_at { Time.current }
  end

  factory :pathway_transition do
    person
    to_stage factory: :pathway_stage
    direction { "placed" }
    occurred_at { Time.current }
  end
end
