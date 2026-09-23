class Website::PagesController < Website::BaseController
  before_action :require_manage!
  before_action :set_page, except: %i[ new create ]

  def new
    @page = @site.pages.new(kind: "custom")
  end

  def create
    @page = @site.pages.new(params.expect(page: %i[ title slug show_in_nav ]).merge(kind: "custom"))
    if @page.save
      redirect_to website_page_path(@page), notice: "Page added. Add sections to build it."
    else
      render :new, status: :unprocessable_content
    end
  end

  # The editor.
  def show
    @definitions = SectionDefinition::Defaults.web_sections.reject { |definition| definition.schema["system_only"] }
  end

  def edit
  end

  def update
    if @page.update(params.expect(page: %i[ title slug show_in_nav seo_title seo_description ]))
      @site.expire_cache!
      redirect_to website_page_path(@page), notice: "Page saved."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    return redirect_to(website_page_path(@page), alert: "The home page can't be deleted.") if @page.home?

    @page.destroy!
    @site.expire_cache!
    redirect_to website_path, notice: "#{@page.title} deleted.", status: :see_other
  end

  def preview
    @width = params[:width] == "mobile" ? 390 : 1280
    result = Site::Renderer.new(@site, @page, base_url: request.base_url, draft: true).render
    links = Site::PreviewLinks.new(@site, editor_path: ->(page) { website_page_path(page) })
    @result = result.with(html: links.rewrite(result.html))
    render layout: false
  end

  def publish
    @page.publish!
    redirect_to website_page_path(@page), notice: @site.published? ? "Published. It's live at #{@site.host}#{@page.path}." : "Published. Turn the site on from the Website page to make it public."
  end

  def unpublish
    @page.unpublish!
    redirect_to website_page_path(@page), notice: "Unpublished. Visitors can't see this page.", status: :see_other
  end

  def discard
    @page.discard_draft!
    redirect_to website_page_path(@page), notice: "Draft changes discarded.", status: :see_other
  end

  def move
    @page.reposition(params.expect(:position))
    @site.expire_cache!
    head :no_content
  end

  private
    def set_page
      @page = @site.pages.find(params.expect(:id))
    end
end
