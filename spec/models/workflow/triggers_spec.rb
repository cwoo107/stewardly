require "rails_helper"

RSpec.describe "Workflow triggers" do
  include ActiveJob::TestHelper

  let(:marker) { create(:tag, name: "Ran") }

  def listen(trigger)
    create(:workflow, :published, trigger:, steps: [ Workflow::Steps.build("add_tag").tap { |s| s["config"] = { "tag_id" => marker.id } } ])
  end

  def ran?(person) = person.reload.tags.include?(marker)

  it "starts on a new person" do
    listen("type" => "person_created", "config" => {})
    person = perform_enqueued_jobs { create(:person) }
    expect(ran?(person)).to be(true)
  end

  it "starts on the chosen tag only" do
    wanted = create(:tag)
    listen("type" => "tag_added", "config" => { "tag_id" => wanted.id })
    person = create(:person)
    perform_enqueued_jobs { create(:tagging, person:) }
    expect(ran?(person)).to be(false)
    perform_enqueued_jobs { create(:tagging, person:, tag: wanted) }
    expect(ran?(person)).to be(true)
  end

  it "starts on joining a group, and on a first visit" do
    listen("type" => "group_joined", "config" => {})
    listen("type" => "first_visit", "config" => {})
    joiner = create(:person)
    perform_enqueued_jobs { create(:group_membership, person: joiner) }
    visitor = create(:person)
    perform_enqueued_jobs { create(:attendance, person: visitor, first_time: true) }
    expect([ ran?(joiner), ran?(visitor) ]).to eq([ true, true ])
  end

  it "starts on a form submission once it's processed" do
    form = create(:form, :published)
    listen("type" => "form_submitted", "config" => { "form_id" => form.id })
    user = create(:user)
    person = user.person
    submission = create(:form_submission, form:, user:)
    perform_enqueued_jobs { FormSubmission::Processing.new(submission).process! }
    expect(ran?(person)).to be(true)
  end

  it "doesn't enqueue anything when no workflow listens" do
    expect { create(:person) }.not_to have_enqueued_job(WorkflowTriggerJob)
  end

  describe "the daily sweep" do
    it "starts people who missed N weeks, once per absence" do
      listen("type" => "missed_weeks", "config" => { "weeks" => 3 })
      regular, recent, newcomer = create_list(:person, 3)
      [ 6, 5 ].each { |weeks| create(:attendance, person: regular, checked_in_at: weeks.weeks.ago) }
      [ 6, 1 ].each { |weeks| create(:attendance, person: recent, checked_in_at: weeks.weeks.ago) }
      create(:attendance, person: newcomer, checked_in_at: 5.weeks.ago)

      perform_enqueued_jobs { Workflow::Sweep.new(church).run! }
      expect([ ran?(regular), ran?(recent), ran?(newcomer) ]).to eq([ true, false, false ])
      travel(1.day) { Workflow::Sweep.new(church).run! }
      expect(WorkflowRun.where(person: regular).count).to eq(1)
    end

    it "starts people N days after a date, and on birthdays" do
      listen("type" => "date_relative", "config" => { "date_field" => "created_at", "days" => 7 })
      listen("type" => "date_relative", "config" => { "date_field" => "birthdate", "days" => 0 })
      week_old = travel(-7.days) { create(:person) }
      birthday = create(:person, birthdate: church.today.change(year: 1990))
      perform_enqueued_jobs { Workflow::Sweep.new(church).run! }
      expect([ ran?(week_old), ran?(birthday) ]).to eq([ true, true ])
    end
  end
end
