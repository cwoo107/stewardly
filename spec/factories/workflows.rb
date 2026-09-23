FactoryBot.define do
  factory :workflow do
    sequence(:name) { |n| "Workflow #{n}" }
    draft_definition { { "trigger" => { "type" => "first_visit", "config" => {} }, "steps" => [] } }

    # Publishes the given steps: create(:workflow, :published, steps: [...])
    transient do
      steps { nil }
      trigger { nil }
    end

    trait :published do
      after(:create) do |workflow, context|
        definition = workflow.draft_definition.merge("steps" => context.steps || [ Workflow::Steps.build("add_tag").tap { |s| s["config"] = { "tag_id" => create(:tag).id } } ])
        definition["trigger"] = context.trigger if context.trigger
        workflow.update!(draft_definition: definition)
        workflow.publish!
      end
    end
  end

  factory :workflow_version do
    workflow
    sequence(:number)
    definition { { "trigger" => { "type" => "person_created" }, "steps" => [] } }
    published_at { Time.current }
  end

  factory :workflow_run do
    workflow
    workflow_version { association :workflow_version, workflow: }
    person
    started_at { Time.current }
  end

  factory :workflow_step_execution do
    workflow_run
    step_id { SecureRandom.alphanumeric(8) }
    step_type { "wait" }
  end

  factory :message_draft do
    workflow_step_execution
    person
    subject { "Hello" }
    body { "Hi there" }
    source { "ai" }
  end

  factory :ai_request do
    purpose { "workflow_draft" }
    provider { "ollama" }
  end

  factory :campaign_extra_recipient do
    campaign
    person
  end
end
