require "rails_helper"

RSpec.describe Workflow do
  include ActiveJob::TestHelper

  let(:tag) { create(:tag) }
  let(:person) { create(:person) }

  def tag_step(tag) = Workflow::Steps.build("add_tag").tap { |step| step["config"] = { "tag_id" => tag.id } }
  def wait_step(days) = Workflow::Steps.build("wait").tap { |step| step["config"].merge!("amount" => days, "unit" => "days") }

  it "publishes numbered versions and keeps in-flight runs on theirs" do
    workflow = create(:workflow, :published, steps: [ wait_step(1), tag_step(tag) ])
    run = Workflow::Enrollment.new(workflow, person).start!
    perform_enqueued_jobs(only: WorkflowStepJob)
    expect(run.reload).to be_waiting

    new_tag = create(:tag)
    workflow.update_step!(workflow.draft.steps.last["id"], "tag_id" => new_tag.id)
    workflow.publish!
    expect(workflow.versions.pluck(:number)).to eq([ 2, 1 ])

    travel(2.days) { 2.times { perform_enqueued_jobs(only: WorkflowStepJob) } }
    expect(run.reload).to be_completed
    expect(person.tags).to contain_exactly(tag) # version 1's step
  end

  it "won't publish with problems" do
    workflow = create(:workflow, draft_definition: { "trigger" => { "type" => "tag_added" }, "steps" => [] })
    expect { workflow.publish! }.to raise_error(ArgumentError, /needs a tag/)
  end

  it "doesn't let someone into the same workflow twice at once, unless allowed" do
    workflow = create(:workflow, :published, steps: [ wait_step(3) ])
    expect(Workflow::Enrollment.new(workflow, person).start!).to be_present
    expect(Workflow::Enrollment.new(workflow, person).start!).to be_nil

    workflow.update!(allow_reentry: true)
    expect(Workflow::Enrollment.new(workflow, person).start!).to be_present
  end

  it "checks entry conditions" do
    workflow = create(:workflow, draft_definition: { "trigger" => { "type" => "first_visit" }, "steps" => [ tag_step(tag) ],
      "entry" => { "match" => "all", "conditions" => [ { "type" => "membership_status", "statuses" => [ "member" ] } ] } })
    workflow.publish!
    expect(Workflow::Enrollment.new(workflow, create(:person, membership_status: "guest")).start!).to be_nil
    expect(Workflow::Enrollment.new(workflow, create(:person, membership_status: "member")).start!).to be_present
  end

  it "pauses runs at their next step and picks them up on resume; the kill switch cancels them" do
    workflow = create(:workflow, :published, steps: [ tag_step(tag), tag_step(create(:tag)) ])
    run = Workflow::Enrollment.new(workflow, person).start!
    workflow.pause!
    perform_enqueued_jobs(only: WorkflowStepJob)
    expect(run.reload).to be_waiting
    expect(person.tags).to be_empty

    perform_enqueued_jobs { workflow.resume! }
    expect(run.reload).to be_completed
    expect(person.tags.count).to eq(2)

    other = Workflow::Enrollment.new(workflow, create(:person)).start!
    workflow.stop_all_runs!
    expect(other.reload).to be_cancelled
  end
end
