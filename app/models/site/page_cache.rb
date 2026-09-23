# Published pages, rendered once and kept in Redis. The key includes the site's
# content_version, which publishing (and changes to events, groups, forms, services, and
# campuses) bumps; the expiry is a backstop for time passing (an event ending).
module Site::PageCache
  EXPIRES_IN = 15.minutes

  def self.fetch(site, page)
    key = [ "site-page", site.id, site.content_version, site.theme_key, page.id, page.published_at.to_i ]
    Rails.cache.fetch(key, expires_in: EXPIRES_IN) { render(site, page) }
  end

  def self.render(site, page, not_found: false)
    if not_found
      page.published_sections = [ { "id" => "404", "key" => "text", "settings" => { "heading" => "We couldn't find that page",
        "body" => "It may have moved. [Go to the home page](/)", "align" => "center" } } ]
    end
    result = Site::Renderer.new(site, page).render
    Rails.logger.warn("[sites] #{site.id} page #{page.id}: #{result.errors.join("; ")}") if result.errors.any?
    result.html
  end
end
