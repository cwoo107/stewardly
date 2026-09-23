class Sites::PagesController < Sites::BaseController
  def show
    return render_not_found unless site.published?

    page = site.pages.where.not(published_at: nil).find_by(slug: params[:path].to_s.delete_suffix("/"))
    return render_not_found unless page

    expires_in 5.minutes, public: true
    render html: Site::PageCache.fetch(site, page).html_safe
  end

  def sitemap
    @pages = site.published? ? site.pages.where.not(published_at: nil) : []
    render formats: :xml
  end

  def robots
    render plain: "User-agent: *\nAllow: /\nSitemap: #{site.base_url}/sitemap.xml\n"
  end
end
