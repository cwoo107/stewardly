require "rails_helper"

RSpec.describe "Workflows" do
  include ActiveJob::TestHelper

  let(:tag) { create(:tag) }

  context "as staff" do
    let(:user) { create(:user, :staff) }

    before { sign_in_as(user) }

    it "installs the starter workflows as drafts" do
      get workflows_path
      expect(response.body).to include("New member welcome", "First-time guest follow-up", "Missed 3 weeks check-in")
      expect(Workflow.pluck(:status).uniq).to eq([ "draft" ])
    end

    it "builds a workflow with a branch, publishes it, and runs a person through it" do
      post workflows_path, params: { workflow: { name: "Newcomers" } }
      workflow = Workflow.find_by!(name: "Newcomers")
      expect(response).to redirect_to(edit_workflow_trigger_path(workflow))

      get edit_workflow_trigger_path(workflow, type: "tag_added")
      expect(response.body).to include("trigger[config][tag_id]")
      patch workflow_trigger_path(workflow), params: { trigger: { type: "tag_added", config: { tag_id: tag.id } },
        workflow_entry: { definition: { match: "all", conditions: { "0" => { type: "membership_status", statuses: [ "guest" ] } } } } }
      expect(workflow.reload.draft.trigger.to_h).to eq("type" => "tag_added", "config" => { "tag_id" => tag.id.to_s })

      post workflow_steps_path(workflow), params: { type: "condition" }
      condition = workflow.reload.draft.steps.last
      expect(response).to redirect_to(edit_workflow_path(workflow, editing: condition["id"], anchor: "step_#{condition["id"]}"))
      get edit_workflow_step_path(workflow, condition["id"])
      expect(response.body).to include("workflow_condition[definition][match]")
      patch workflow_step_path(workflow, condition["id"]), params: { workflow_condition: { definition: { match: "all",
        conditions: { "0" => { type: "age", min: "18" } } } } }

      post workflow_steps_path(workflow), params: { type: "create_task", parent_id: condition["id"], branch: "yes" }
      task_step = workflow.reload.draft.find(condition["id"])["yes"].first
      patch workflow_step_path(workflow, task_step["id"]), params: { config: { title: "Call {{ person.first_name }}", owner_id: user.id, due_in_days: "1", priority: "high" } }

      get edit_workflow_path(workflow)
      expect(response.body).to include("If Age at least 18", "Task for #{user.name}: Call {{ person.first_name }}", "If yes", "If no", "Publish")

      patch publish_workflow_path(workflow)
      expect(workflow.reload).to be_active
      expect(workflow.current_version.number).to eq(1)

      adult = create(:person, first_name: "Ana", birthdate: 30.years.ago, membership_status: "guest")
      perform_enqueued_jobs { create(:tagging, person: adult, tag:) }
      expect(Task.last).to have_attributes(title: "Call Ana", owner: user, priority: "high")
      run = workflow.runs.last
      expect(run).to be_completed

      get workflow_run_path(workflow, run)
      expect(response.body).to include("Ana", "Completed", "Open the task")
      get person_path(adult)
      expect(response.body).to include("Workflows", "Newcomers")
    end

    it "reorders and removes steps, and pauses, resumes, and stops runs" do
      workflow = create(:workflow)
      first = workflow.add_step!("update_pathway")
      second = workflow.add_step!("add_tag")
      patch move_workflow_step_path(workflow, second["id"]), params: { position: 0 }
      expect(workflow.reload.draft.steps.map { |s| s["id"] }).to eq([ second["id"], first["id"] ])
      delete workflow_step_path(workflow, first["id"])
      expect(workflow.reload.draft.steps.size).to eq(1)

      patch publish_workflow_path(workflow)
      expect(flash[:alert]).to include("choose a tag")

      live = create(:workflow, :published)
      patch pause_workflow_path(live)
      expect(live.reload).to be_paused
      expect { patch resume_workflow_path(live) }.to have_enqueued_job(WorkflowResumeJob)
      Workflow::Enrollment.new(live.reload, create(:person)).start!
      patch stop_runs_workflow_path(live)
      expect(live.runs.last).to be_cancelled
    end

    it "can't turn on sending AI messages without review" do
      workflow = create(:workflow)
      step = workflow.add_step!("ai_draft")
      patch workflow_step_path(workflow, step["id"]), params: { config: { instructions: "Hi", subject: "Hi", auto_send: "1" } }
      expect(workflow.reload.draft.find(step["id"]).dig("config", "auto_send")).to be(false)
      expect(AuditEvent.where(action: "workflow.auto_send_enabled")).to be_empty
    end

    it "reviews, edits, and sends drafts from the approval queue" do
      church.update!(mailing_address: "1 Church St")
      workflow = create(:workflow, :published)
      run = Workflow::Enrollment.new(workflow, create(:person, first_name: "Ben"))
      run = run.start!
      execution = create(:workflow_step_execution, workflow_run: run, step_type: "ai_draft")
      draft = create(:message_draft, workflow_step_execution: execution, person: run.person, email_topic: EmailTopic.default!, body: "Draft text")

      get message_drafts_path
      expect(response.body).to include("Approvals (1)", "Draft text", "Ben")
      perform_enqueued_jobs { patch message_draft_path(draft), params: { message_draft: { subject: "Welcome", body: "Edited text" } } }
      expect(draft.reload).to have_attributes(status: "sent", body: "Edited text", reviewed_by: user)
      expect(ActionMailer::Base.deliveries.last.html_part.decoded).to include("Edited text")

      other = create(:message_draft, workflow_step_execution: create(:workflow_step_execution, workflow_run: run), person: run.person)
      patch reject_message_draft_path(other)
      expect(other.reload).to be_rejected
    end
  end

  context "as a church admin" do
    before { sign_in_as(create(:user, :church_admin)) }

    it "turns on auto-send for an AI step and records it in the audit log" do
      workflow = create(:workflow)
      step = workflow.add_step!("ai_draft")
      patch workflow_step_path(workflow, step["id"]), params: { config: { instructions: "Hi", subject: "Hi", auto_send: "1" } }
      expect(workflow.reload.draft.find(step["id"]).dig("config", "auto_send")).to be(true)
      expect(AuditEvent.last).to have_attributes(action: "workflow.auto_send_enabled", auditable: workflow)
    end

    it "switches AI on and sets the limits" do
      patch church_settings_path, params: { church: { ai_enabled: "1", ai_monthly_token_cap: "50000", workflow_daily_send_limit: "200" } }
      expect(church.reload).to have_attributes(ai_enabled: true, ai_monthly_token_cap: 50_000, workflow_daily_send_limit: 200)
    end
  end

  it "keeps workflows and approvals from members" do
    sign_in_as(create(:user, :member))
    get workflows_path
    expect(response).to have_http_status(:forbidden)
    get message_drafts_path
    expect(response).to have_http_status(:forbidden)
  end
end
