# The website overview: address, pages (drag to reorder the menu), theme, domains.
class WebsitesController < ApplicationController
  before_action :set_site

  def show
    @pages = @site.pages
    @domains = @site.domains.order(:created_at)
  end

  def update
    attributes = params.expect(site: %i[ name published ])
    was_published = @site.published?
    @site.update!(attributes)
    @site.update!(published_at: Time.current) if @site.published? && !was_published
    @site.expire_cache!
    redirect_to website_path, notice: @site.published? ? "Your site is live at #{@site.host}." : "Saved."
  end

  private
    def set_site
      authorize :website, action_name == "show" ? :show? : :update?
      @site = Site.current
    end
end
