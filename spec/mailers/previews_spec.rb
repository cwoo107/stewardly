require "rails_helper"
Rails.root.glob("spec/mailers/previews/*_preview.rb").each { |file| require file }

# Every mailer has a preview (plus campaign, workflow, and AI-drafted emails), and every
# preview renders against real records. Browse them in development at /rails/mailers.
RSpec.describe "Mailer previews" do
  before do
    church.update!(subdomain: "grace", contact_email: "office@grace.test") # leader emails fall back to the office
    assignment = create(:assignment, person: create(:person, email: "vol@example.com"))
    assignment.update!(status: "accepted")
    create(:registration, person: create(:person, email: "reg@example.com"))
    create(:enrollment, person: create(:person, email: "class@example.com"))
    create(:group_join_request, person: create(:person, email: "join@example.com"))
    create(:person, email: "newcomer@example.com")
    church.update!(mailing_address: "1 Church St")
    create(:user, :staff)
    create(:insight, title: "Follow up with Rae")
    template = create(:email_template).tap { |t| t.add_section!("text") }
    create(:campaign, email_template: template)
    workflow = create(:workflow, :published, steps: [ Workflow::Steps.build("send_email").tap { |s| s["config"].merge!("email_template_id" => template.id, "email_topic_id" => EmailTopic.default!.id, "subject" => "Welcome, {{ person.first_name }}") } ])
    run = Workflow::Enrollment.new(workflow, create(:person, email: "run@example.com")).start!
    create(:message_draft, workflow_step_execution: create(:workflow_step_execution, workflow_run: run), person: run.person, body: "So glad you came!")
  end

  ActionMailer::Preview.all.each do |preview|
    preview.emails.each do |email|
      it "renders #{preview.preview_name}##{email}" do
        ActsAsTenant.test_tenant = nil # like /rails/mailers: no church until the preview sets one
        message = preview.call(email)
        expect(message.to).to be_present
        html = (message.html_part || message).decoded
        expect(html).to include("Church") # rendered with the church's details
        expect(html).not_to include("{{", "{%") # no unrendered Liquid
        own_links = html.scan(%r{https?://[^"'\s<>]+}).select { |url| URI.parse(url).host.to_s.end_with?("localhost") rescue false }
        expect(own_links).to all(match(%r{\Ahttp://#{church.subdomain}(\.sites)?\.localhost/})) # never the bare app domain
      end
    end
  end
end
