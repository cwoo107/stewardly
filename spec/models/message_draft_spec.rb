require "rails_helper"

RSpec.describe MessageDraft do
  include ActiveJob::TestHelper

  let(:person) { create(:person, first_name: "Ana") }
  let(:topic) { EmailTopic.default! }
  let(:step) do
    Workflow::Steps.build("ai_draft").tap do |s|
      s["config"].merge!("instructions" => "Welcome them", "subject" => "Hi {{ person.first_name }}", "email_topic_id" => topic.id)
    end
  end
  let(:reply) { Assistant::Providers::Reply.new(text: "So glad you came, Ana. {{ oops }}", input_tokens: 1, output_tokens: 1, raw: {}) }

  before do
    church.update!(mailing_address: "1 Church St", ai_enabled: true)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("AI_MODEL").and_return("llama3.1")
    allow_any_instance_of(Assistant::Providers::Ollama).to receive(:chat).and_return(reply)
  end

  def run_workflow
    workflow = create(:workflow, :published, steps: [ step ])
    perform_enqueued_jobs { Workflow::Enrollment.new(workflow, person).start! }
  end

  it "queues an AI draft for approval without sending it, and never shows the AI private details" do
    run_workflow
    draft = MessageDraft.last
    expect(draft).to have_attributes(status: "pending", source: "ai", subject: "Hi Ana", body: include("So glad you came"))
    expect(ActionMailer::Base.deliveries).to be_empty

    prompt = draft.ai_request.prompt.to_json
    expect(prompt).to include("Ana", "Welcome them")
    expect(prompt).not_to include(person.email, person.last_name)
  end

  it "sends the approved (edited) draft once, treating drafted text as text rather than Liquid" do
    run_workflow
    draft = MessageDraft.last
    perform_enqueued_jobs { draft.approve!(body: "Edited: so glad you came {{ oops }}") }
    mail = ActionMailer::Base.deliveries.last
    expect(mail.subject).to eq("Hi Ana")
    expect(mail.html_part.decoded).to include("Edited: so glad you came")
    expect { draft.approve! }.to raise_error(ArgumentError, /already sent/)
    expect(ActionMailer::Base.deliveries.size).to eq(1)
  end

  it "sends straight away when a church admin turned on auto-send" do
    step["config"]["auto_send"] = true
    run_workflow
    expect(MessageDraft.last).to have_attributes(status: "sent", auto_sent: true)
    expect(ActionMailer::Base.deliveries.size).to eq(1)
  end

  it "still queues a draft for staff to write when AI is off" do
    church.update!(ai_enabled: false)
    run_workflow
    expect(MessageDraft.last).to have_attributes(status: "pending", source: "staff", body: nil, note: include("turned off"))
  end
end
