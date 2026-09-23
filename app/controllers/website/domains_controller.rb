class Website::DomainsController < Website::BaseController
  before_action :require_develop!
  before_action :set_domain, only: %i[ destroy check primary ]

  def create
    domain = @site.domains.new(hostname: params.expect(site_domain: [ :hostname ])[:hostname])
    if domain.save
      SiteDomainVerificationJob.perform_later(domain)
      redirect_to website_path(anchor: "domains"), notice: "#{domain.hostname} added. Point its DNS at us (below) and we'll check every hour."
    else
      redirect_to website_path(anchor: "domains"), alert: domain.errors.full_messages.to_sentence
    end
  end

  def check
    result = @domain.verify!
    redirect_to website_path(anchor: "domains"), (result.ok ? :notice : :alert) => "#{@domain.hostname}: #{result.message}"
  end

  def primary
    @domain.make_primary!
    redirect_to website_path(anchor: "domains"), notice: "#{@domain.hostname} is now the main address."
  end

  def destroy
    @domain.destroy!
    redirect_to website_path(anchor: "domains"), notice: "#{@domain.hostname} removed.", status: :see_other
  end

  private
    def set_domain
      @domain = @site.domains.find(params.expect(:id))
    end
end
