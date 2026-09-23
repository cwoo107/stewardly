# One workflow email to one person: compiled from a template (optionally with a drafted
# body in place of its first text section), stored as a Delivery unique to the step
# execution, and sent through the same pipeline as campaigns.
class Workflow::Mailing
  def initialize(execution, person:, template:, topic:, subject:, body: nil)
    @execution = execution
    @person = person
    @template = template
    @topic = topic
    @subject = subject
    @body = body
  end

  # The Delivery, or nil when the person has no email address.
  def deliver!
    return if @person.email.blank?

    delivery = Delivery.find_by(workflow_step_execution: @execution) || create_delivery
    Delivery::Sending.new(delivery).send! if delivery.queued?
    delivery.reload
  end

  # A template with the drafted body as its first text section (or a plain one).
  def self.with_body(template, body, church:)
    # Drafted text is shown as written: stop it being read as Liquid when personalising.
    safe = body.to_s.gsub(/\{([{%])/) { "{​#{Regexp.last_match(1)}" }
    base = template&.dup || EmailTemplate.new(name: "Message", church:)
    sections = base.sections.deep_dup
    text = sections.find { |section| section["key"] == "text" }
    text ? text["settings"] = text["settings"].to_h.merge("body" => safe, "heading" => nil) : sections << { "id" => "body", "key" => "text", "settings" => { "body" => safe } }
    base.sections = sections
    base
  end

  private
    def church = @execution.church

    def create_delivery
      template = @body ? self.class.with_body(@template, @body, church:) : @template
      html = EmailTemplate::Renderer.new(template, church:).compile(tracking: Email::Tracking.new(church))
      Delivery.create!(workflow_step_execution: @execution, person: @person, email: @person.email, email_topic: @topic,
        subject: @subject, html_snapshot: html)
    rescue ActiveRecord::RecordNotUnique
      Delivery.find_by!(workflow_step_execution: @execution)
    end
end
