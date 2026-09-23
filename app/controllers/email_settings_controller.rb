# Sending address, postal address, provider connections, and DNS guidance.
class EmailSettingsController < ApplicationController
  before_action :authorize_settings

  def show
    @church = Current.church
    @integrations = Integration.all.index_by(&:category)
  end

  def update
    @church = Current.church
    if @church.update(params.expect(church: %i[ mailing_address email_from_domain ]))
      redirect_to email_settings_path, notice: "Email settings saved."
    else
      @integrations = Integration.all.index_by(&:category)
      render :show, status: :unprocessable_content
    end
  end

  # SPF/DMARC check, loaded into a Turbo Frame (DNS lookups can be slow).
  def dns
    domain = Current.church.email_from_domain
    @records = domain.present? ? Email::DomainCheck.new(domain, provider: Current.church.email_integration&.provider).records : []
    render layout: false
  end

  private
    def authorize_settings
      authorize :email_settings, action_name == "update" ? :update? : :show?
    end
end
