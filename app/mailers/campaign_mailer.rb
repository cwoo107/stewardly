# Test sends from the template editor. Real campaigns don't use Action Mailer; they go
# through Delivery::Sending so each recipient gets their own links and headers.
class CampaignMailer < ApplicationMailer
  def test
    template = params[:template]
    person = params[:person]
    html = EmailTemplate::Renderer.new(template).preview(person)
    subject = EmailTemplate::Renderer.personalize(template.subject.presence || template.name, person:, links: Email::Drops::Links.new(unsubscribe: "#", preferences: "#"))
    mail(to: person.email, subject: "[Test] #{subject}") do |format|
      format.text { render plain: Email::Message.text_from(html) }
      format.html { render html: html.html_safe }
    end
  end
end
