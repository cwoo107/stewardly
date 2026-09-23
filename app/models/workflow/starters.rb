# Ready-made workflows every church starts with, installed as drafts: staff choose
# the people and templates, then publish.
module Workflow::Starters
  def self.install!
    STARTERS.each do |key, starter|
      next if Workflow.exists?(starter_key: key)

      Workflow.create!(starter_key: key, name: starter[:name], description: starter[:description], draft_definition: definition(starter))
    end
  end

  STARTERS = {
    "new_member_welcome" => {
      name: "New member welcome",
      description: "When someone is tagged New member: a welcome email, a dinner invitation on day 3, a pastor's call on day 7, " \
        "and an alert on day 30 if they're still in Connect.",
      trigger: -> { { "type" => "tag_added", "config" => { "tag_id" => Tag.find_or_create_by!(name: "New member") { |t| t.color = "green" }.id } } },
      steps: -> {
        connect = Pathway.current.stages.first
        [
          step("send_email", "email_template_id" => template("Announcement"), "email_topic_id" => EmailTopic.default!.id,
            "subject" => "Welcome to {{ church.name }}, {{ person.first_name }}!"),
          step("wait", "mode" => "duration", "amount" => 3, "unit" => "days", "time" => "09:00"),
          step("send_email", "email_template_id" => template("Event invitation"), "email_topic_id" => EmailTopic.default!.id,
            "subject" => "Join us for our new member dinner"),
          step("wait", "mode" => "duration", "amount" => 4, "unit" => "days", "time" => "09:00"),
          step("create_task", "title" => "Call {{ person.name }} to welcome them", "due_in_days" => 2, "priority" => "high"),
          step("wait", "mode" => "duration", "amount" => 23, "unit" => "days", "time" => "09:00"),
          step("update_pathway", {}),
          step("condition", { "match" => "all", "conditions" => [ { "type" => "pathway_stage", "stage_ids" => [ connect&.id.to_s ].compact } ] },
            yes: [ step("notify_staff", "user_ids" => [], "message" => "{{ person.name }} became a member 30 days ago and is still in Connect.") ])
        ]
      }
    },
    "first_time_guest" => {
      name: "First-time guest follow-up",
      description: "After a first visit: a thank-you note (drafted for approval), a follow-up task, and an alert if they don't come back within two weeks.",
      trigger: -> { { "type" => "first_visit", "config" => {} } },
      steps: -> {
        [
          step("ai_draft", "instructions" => "Thank them for visiting on Sunday, say we'd love to see them again, and mention they can reply with any questions.",
            "subject" => "Thanks for visiting, {{ person.first_name }}", "email_topic_id" => EmailTopic.default!.id, "auto_send" => false),
          step("create_task", "title" => "Follow up with first-time guest {{ person.name }}", "due_in_days" => 3, "priority" => "normal"),
          step("wait", "mode" => "duration", "amount" => 2, "unit" => "weeks", "time" => "09:00"),
          step("condition", { "match" => "all", "conditions" => [ { "type" => "attendance", "times" => 2, "days" => 21 } ] },
            no: [ step("notify_staff", "user_ids" => [], "message" => "{{ person.name }} visited for the first time two weeks ago and hasn't been back.") ])
        ]
      }
    },
    "missed_three_weeks" => {
      name: "Missed 3 weeks check-in",
      description: "When a regular attender misses three weeks: a “we miss you” note for approval and a check-in task.",
      trigger: -> { { "type" => "missed_weeks", "config" => { "weeks" => 3 } } },
      steps: -> {
        [
          step("ai_draft", "instructions" => "Let them know we've missed them the last few Sundays and we're thinking of them. No guilt, just warmth.",
            "subject" => "We've missed you, {{ person.first_name }}", "email_topic_id" => EmailTopic.default!.id, "auto_send" => false),
          step("create_task", "title" => "Check in with {{ person.name }}", "due_in_days" => 3, "priority" => "normal")
        ]
      }
    }
  }.freeze

  def self.definition(starter)
    { "trigger" => starter[:trigger].call, "entry" => { "match" => "all", "conditions" => [] }, "steps" => starter[:steps].call }
  end

  # step("wait", "amount" => 3) or step("condition", { rules }, yes: [ ... ]). Takes no keyword
  # arguments, so string-keyed settings always land in config.
  def self.step(type, config, branches = {})
    Workflow::Steps.build(type).tap do |step|
      step["config"] = step["config"].merge(config)
      step.merge!("yes" => branches.fetch(:yes, []), "no" => branches.fetch(:no, [])) if type == "condition"
    end
  end

  def self.template(name) = EmailTemplate.find_by(name:)&.id
end
