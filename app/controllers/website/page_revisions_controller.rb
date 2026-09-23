class Website::PageRevisionsController < Website::BaseController
  before_action :require_manage!
  before_action :set_page

  def index
    skip_policy_scope # the page's own revisions, authorized by manage_website
    @revisions = @page.revisions.includes(published_by: :person)
  end

  def restore
    @page.restore!(@page.revisions.find(params.expect(:id)))
    redirect_to website_page_path(@page), notice: "That version is now your draft. Publish to make it live."
  end

  private
    def set_page
      @page = @site.pages.find(params.expect(:page_id))
    end
end
