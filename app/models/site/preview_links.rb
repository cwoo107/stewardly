# The editor's preview is a sandboxed srcdoc frame with no address of its own, so a link
# like "/about" would resolve against the admin app. In the preview only:
#   - links to one of the site's pages open that page in the editor (whose preview shows its draft);
#   - other site links (/f/..., /e/...) and outside links open in a new tab, at the real site address.
# Visitors' pages are never rewritten.
class Site::PreviewLinks
  def initialize(site, editor_path:)
    @site = site
    @editor_path = editor_path # ->(page) { "/website/pages/1" }
    @pages = site.pages.index_by(&:path)
  end

  def rewrite(html)
    document = Nokogiri::HTML5(html)
    document.css("a[href]").each do |link|
      href = link["href"].to_s.strip
      next if href.start_with?("#", "mailto:", "tel:")

      if href.start_with?("/") && !href.start_with?("//")
        path = href.split(/[?#]/).first.presence || "/"
        page = @pages[path.delete_suffix("/").presence || "/"]
        page ? top(link, @editor_path.call(page)) : new_tab(link, "#{@site.base_url}#{href}")
      else
        new_tab(link, href)
      end
    end
    document.to_html
  end

  private
    def top(link, href)
      link["href"] = href
      link["target"] = "_top"
    end

    def new_tab(link, href)
      link["href"] = href
      link["target"] = "_blank"
      link["rel"] = "noopener"
    end
end
