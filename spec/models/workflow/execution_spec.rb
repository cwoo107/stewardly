require "rails_helper"

RSpec.describe Workflow::Execution do
  include ActiveJob::TestHelper

  let(:person) { create(:person, first_name: "Ana") }
  let(:template) { create(:email_template).tap { |t| t.add_section!("text") } }
  let(:topic) { EmailTopic.default! }

  before { church.update!(mailing_address: "1 Church St") }

  def build(type, config = {}, branches = {})
    Workflow::Steps.build(type).tap do |step|
      step["config"] = step["config"].merge(config)
      branches.each { |branch, steps| step[branch.to_s] = steps }
    end
  end

  def run_through(steps, trigger: nil)
    workflow = create(:workflow, :published, steps:, trigger:)
    run = nil
    perform_enqueued_jobs { run = Workflow::Enrollment.new(workflow, person).start! }
    run.reload
  end

  it "sends a workflow email once, even when the step job runs again" do
    email = build("send_email", "email_template_id" => template.id, "email_topic_id" => topic.id, "subject" => "Welcome, {{ person.first_name }}")
    run = run_through([ email ])
    expect(run).to be_completed
    expect(ActionMailer::Base.deliveries.map(&:subject)).to eq([ "Welcome, Ana" ])

    run.update!(status: :active, current_step_id: email["id"])
    perform_enqueued_jobs { WorkflowStepJob.perform_now(run, email["id"]) }
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(person.deliveries.count).to eq(1)
    expect(person.touchpoints.workflow_message.count).to eq(1)
  end

  it "follows the yes or no branch, then carries on" do
    member_tag, guest_tag, after = create_list(:tag, 3)
    condition = build("condition", { "match" => "all", "conditions" => [ { "type" => "membership_status", "statuses" => [ "member" ] } ] },
      yes: [ build("add_tag", "tag_id" => member_tag.id) ], no: [ build("add_tag", "tag_id" => guest_tag.id) ])
    person.update!(membership_status: "guest")
    run_through([ condition, build("add_tag", "tag_id" => after.id) ])
    expect(person.tags).to contain_exactly(guest_tag, after)
    expect(WorkflowStepExecution.find_by(step_id: condition["id"]).result).to include("branch" => "no", "matched" => false)
  end

  it "waits in the church's time zone" do
    church.update!(time_zone: "Pacific Time (US & Canada)")
    travel_to(Time.utc(2026, 9, 23, 20)) do # Wednesday 1pm Pacific
      run = run_through([ build("wait", "mode" => "weekday", "weekday" => "0", "time" => "09:00"), build("add_tag", "tag_id" => create(:tag).id) ])
      expect(run).to be_waiting
      expect(run.wake_at).to eq(church.zone.parse("2026-09-27 09:00"))
    end
  end

  it "defers emails past the daily send limit to the next morning" do
    church.update!(workflow_daily_send_limit: 0)
    run = run_through([ build("send_email", "email_template_id" => template.id, "email_topic_id" => topic.id, "subject" => "Hi") ])
    expect(run).to be_waiting
    expect(run.wake_at.in_time_zone(church.zone).hour).to eq(8)
    expect(ActionMailer::Base.deliveries).to be_empty
  end

  it "creates one task, notifies staff, and adds to a campaign" do
    owner = create(:user, :staff)
    campaign = create(:campaign)
    run = run_through([
      build("create_task", "title" => "Call {{ person.name }}", "owner_id" => owner.id, "due_in_days" => 2),
      build("notify_staff", "user_ids" => [ owner.id.to_s ], "message" => "{{ person.first_name }} joined"),
      build("enroll_in_campaign", "campaign_id" => campaign.id)
    ])
    expect(run).to be_completed, run.step_executions.map { |e| [ e.step_type, e.status, e.error ] }.inspect
    expect(Task.last).to have_attributes(title: "Call #{person.name}", owner:, due_on: church.today + 2)
    expect(ActionMailer::Base.deliveries.last.to).to eq([ owner.email_address ])
    expect(campaign.audience.people).to include(person)
  end

  it "skips adding to a campaign that already went out" do
    campaign = create(:campaign, status: :sent)
    run = run_through([ build("enroll_in_campaign", "campaign_id" => campaign.id) ])
    expect(run.step_executions.last).to be_skipped
    expect(run.step_executions.last.result["reason"]).to include("already sent")
  end

  it "records a failure and can retry the step" do
    step = build("add_tag", "tag_id" => create(:tag).id)
    allow_any_instance_of(Workflow::Steps::AddTag).to receive(:perform).and_raise(RuntimeError, "boom")
    run = run_through([ step ])
    expect(run).to be_failed
    expect(run.step_executions.last).to have_attributes(status: "failed", error: "RuntimeError: boom")

    allow_any_instance_of(Workflow::Steps::AddTag).to receive(:perform).and_call_original
    perform_enqueued_jobs { run.retry! }
    expect(run.reload).to be_completed
  end
end
