class Workflow::Steps::SendEmail < Workflow::Steps::Base
  self.label = "Send an email"

  def errors
    problems = []
    problems << "choose a template" unless exists?(EmailTemplate, "email_template_id")
    problems << "choose a topic" unless exists?(EmailTopic, "email_topic_id")
    problems << "add a subject" if config["subject"].blank?
    problems
  end

  def summary
    template = EmailTemplate.find_by(id: config["email_template_id"])&.name
    template ? "Send “#{template}”" : label
  end

  def perform(run, execution)
    return Outcome.wait(Workflow::SendLimit.new(church).next_opening, "deferred" => "Daily send limit reached") if Workflow::SendLimit.new(church).reached?

    delivery = Workflow::Mailing.new(execution, person: run.person, template: EmailTemplate.find_by(id: config["email_template_id"]),
      topic: EmailTopic.find_by(id: config["email_topic_id"]), subject: config["subject"]).deliver!
    return Outcome.skip("No email address") unless delivery

    Outcome.done("delivery_id" => delivery.id, "delivery_status" => delivery.status)
  end
end
