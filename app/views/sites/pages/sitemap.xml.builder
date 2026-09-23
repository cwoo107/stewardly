xml.instruct!
xml.urlset(xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9") do
  @pages.each do |page|
    xml.url do
      xml.loc "#{Current.site.base_url}#{page.path}"
      xml.lastmod page.published_at.to_date.iso8601
    end
  end
end
