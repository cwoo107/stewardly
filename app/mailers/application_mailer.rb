# Church mail goes out as "<Church name>" from the church's sending domain (or a
# no-reply address on the app domain), with replies going to the church's contact
# email. Delivery goes through the church's provider (Email::ChurchDeliveryMethod).
class ApplicationMailer < ActionMailer::Base
  default from: -> { email_address_with_name(church&.email_from_address || "no-reply@#{Rails.configuration.x.mail_domain}", church&.name || "Stewardly") },
    reply_to: -> { church&.contact_email.presence }
  layout "mailer"

  helper UiHelper

  # Links point back at the church's own subdomain. (Public: route helpers call it.)
  def url_options
    return super unless church

    DemoTunnel.app_host_for(church) ? super.merge(host: church.host, protocol: "https", port: nil) : super.merge(host: church.host)
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
