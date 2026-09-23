# Public church websites. Separate from the admin app: no sign-in, no sessions, no
# browser version gate. The tenant comes from the host (Site.for_host).
class Sites::BaseController < ActionController::Base
  include ChurchTenancy

  skip_forgery_protection # nothing here changes state; forms post to PublicFormsController

  private
    def site = Current.site

    def render_not_found
      page = site.pages.new(title: "Page not found", slug: "not-found", draft_sections: [], published_sections: [])
      html = Site::PageCache.render(site, page, not_found: true)
      render html: html.html_safe, status: :not_found
    end
end
