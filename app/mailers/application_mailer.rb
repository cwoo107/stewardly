# Church mail goes out as "<Church name>" from a no-reply address on the app
# domain, with replies going to the church's contact email. Phase 6 moves
# delivery behind Email::DeliveryProvider.
class ApplicationMailer < ActionMailer::Base
  default from: -> { email_address_with_name("no-reply@#{Rails.configuration.x.mail_domain}", church&.name || "Stewardly") },
    reply_to: -> { church&.contact_email.presence }
  layout "mailer"

  helper UiHelper

  # Links point back at the church's own subdomain. (Public: route helpers call it.)
  def url_options
    church ? super.merge(host: church.host) : super
  end

  private
    def church
      ActsAsTenant.current_tenant
    end

    def mail_person(person, subject:)
      return if person&.email.blank?

      mail(to: email_address_with_name(person.email, person.name), subject:)
    end
end
