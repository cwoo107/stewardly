# Renders a page: each section's Liquid with its settings and the public data drops,
# then the theme layout around them ({{ content_for_layout }}, {{ head }}). Liquid is the
# same strict, resource-limited sandbox as email. A broken section doesn't take the page
# down: it's left out for visitors and shown as an error in the editor's preview.
class Site::Renderer
  Result = Data.define(:html, :errors)

  def initialize(site, page, base_url: site.base_url, draft: false, asset_host: base_url)
    @site = site
    @page = page
    @church = site.church
    @base_url = base_url
    @asset_host = asset_host
    @draft = draft
  end

  def render
    errors = []
    body = sections.map do |section|
      render_section(section)
    rescue Liquid::Error, KeyError => error
      errors << "#{definitions[section["key"]]&.name || section["key"]}: #{error.message}"
      @draft ? %(<div style="margin:1rem;padding:1rem;border:2px dashed #e11d48;color:#9f1239;font:14px system-ui">#{ERB::Util.html_escape(errors.last)}</div>) : ""
    end.join("\n")

    html = Email::Liquid.render(parsed_layout, assigns.merge("content_for_layout" => body, "head" => head))
    Result.new(html:, errors:)
  rescue Liquid::Error => error
    errors << "Layout: #{error.message}"
    Result.new(html: fallback_layout(body.to_s, error), errors:)
  end

  private
    def sections = Array(@draft ? @page.draft_sections : @page.published_sections)
    def definitions = @definitions ||= SectionDefinition::Defaults.web_sections.index_by(&:key)
    def parsed_layout = Email::Liquid.parse(@site.layout)

    # A premium theme's own design for a built-in section, unless the church has edited that section's code.
    def parsed_section(definition)
      return definition.parsed_liquid unless definition.system? && !definition.customized?

      @parsed_sections ||= {}
      @parsed_sections.fetch(definition.key) do
        liquid = @site.theme.section_liquid(definition.key)
        @parsed_sections[definition.key] = liquid ? Email::Liquid.parse(liquid) : definition.parsed_liquid
      end
    end

    def render_section(section)
      definition = definitions.fetch(section["key"])
      settings = definition.settings_schema.to_h { |setting| [ setting["id"], nil ] }.merge(definition.default_settings).merge(section["settings"].to_h)
      background = @site.settings["background_color"]
      EmailTemplate::Renderer.resolve_images(definition.settings_schema, settings, base_url: @base_url, background:)
      if (blocks_schema = definition.blocks_schema)
        settings["blocks"] = Array(settings["blocks"]).map do |block|
          block = blocks_schema["settings"].to_h { |setting| [ setting["id"], nil ] }.merge(block.to_h)
          EmailTemplate::Renderer.resolve_images(blocks_schema["settings"], block, base_url: @base_url, background:)
        end
      end
      settings["video_embed_url"] = self.class.video_embed_url(settings["url"]) if section["key"] == "video"
      Email::Liquid.render(parsed_section(definition), assigns.merge("settings" => settings, "section" => { "id" => section["id"], "key" => section["key"] }))
    end

    # YouTube (privacy-enhanced) and Vimeo only; anything else isn't embedded.
    def self.video_embed_url(url)
      uri = URI.parse(url.to_s) rescue nil
      return unless uri.is_a?(URI::HTTP)

      case uri.host.to_s.delete_prefix("www.").delete_prefix("m.")
      when "youtube.com" then (id = CGI.parse(uri.query.to_s)["v"]&.first) && "https://www.youtube-nocookie.com/embed/#{id[/\A[\w-]{6,20}\z/]}"
      when "youtu.be" then (id = uri.path.delete_prefix("/")[/\A[\w-]{6,20}\z/]) && "https://www.youtube-nocookie.com/embed/#{id}"
      when "vimeo.com" then (id = uri.path[%r{\A/(\d+)}, 1]) && "https://player.vimeo.com/video/#{id}"
      end
    end

    def assigns
      @assigns ||= {
        "site" => Site::Drops::Site.new(@site, page: @page, base_url: @base_url),
        "church" => Site::Drops::Church.new(@church), "page" => Site::Drops::Page.new(@page), "theme" => theme_settings,
        "events" => -> { upcoming_events }, "groups" => -> { groups }, "service_times" => -> { service_times },
        "campuses" => -> { Campus.ordered.map { |campus| Site::Drops::Campus.new(campus) } }, "forms" => -> { forms }
      }
    end

    # Every setting the theme has, blank ones as nil, so layouts can test them under strict variables.
    def theme_settings = @site.theme.settings_schema.to_h { |setting| [ setting["id"], nil ] }.merge(@site.settings)

    def upcoming_events
      EventOccurrence.upcoming.joins(:event).merge(Event.published.where(visibility: "public")).includes(:event).chronological.limit(24)
        .map { |occurrence| Email::Drops::Event.new(occurrence, "#{@base_url}/e/#{occurrence.event.slug}") }
    end

    def groups
      Group.active.alphabetical.includes(:group_memberships).map do |group|
        Site::Drops::Group.new(group, "#{Email::Tracking.base_url(@church)}/me/groups/#{group.id}")
      end
    end

    def service_times = WorshipService.active.ordered.includes(:campus).map { |service| Site::Drops::ServiceTime.new(service) }

    def forms
      published = Form.includes(:fields).where(status: "published", access: "public").where.not(purpose: %w[ event_registration benevolence_request ])
      Site::Drops::Forms.new(published.to_h { |form| [ form.slug, Site::Drops::Form.new(form, -> { Site::Renderer.form_html(form, base_url: @base_url) }) ] })
    end

    # The same fields, spam protections, and endpoint as the form's own page (/f/:slug on the site's host).
    def self.form_html(form, base_url:)
      ApplicationController.renderer.new(http_host: URI.parse(base_url).then { |uri| [ uri.host, uri.port ].compact.join(":") }, https: base_url.start_with?("https"))
        .render(partial: "sites/form", locals: { form: })
    end

    def head
      variables = {
        "--site-brand" => @site.settings["brand_color"], "--site-accent" => @site.settings["accent_color"],
        "--site-bg" => @site.settings["background_color"], "--site-surface" => @site.settings["surface_color"],
        "--site-text" => @site.settings["text_color"],
        "--site-heading-font" => Site::Theme::FONTS.dig(@site.settings["heading_font"], 1), "--site-body-font" => Site::Theme::FONTS.dig(@site.settings["body_font"], 1)
      }.select { |_, value| value.to_s.match?(/\A[#\w\s,'().-]+\z/) }
      title = [ @page.seo_title.presence || (@page.home? ? nil : @page.title), @site.name ].compact.join(" · ")
      helpers = ActionController::Base.helpers
      fonts = Site::Theme.font_stylesheet_url(*@site.settings.values_at("heading_font", "body_font"))
      <<~HTML
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>#{ERB::Util.html_escape(title)}</title>
        #{%(<meta name="description" content="#{ERB::Util.html_escape(@page.seo_description)}">) if @page.seo_description.present?}
        #{'<meta name="robots" content="noindex">' if @draft}
        #{%(<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin><link rel="stylesheet" href="#{ERB::Util.html_escape(fonts)}">) if fonts}
        <link rel="stylesheet" href="#{@asset_host}#{helpers.asset_path("tailwind.css")}">
        <link rel="stylesheet" href="#{@asset_host}#{helpers.asset_path("#{@site.theme.stylesheet}.css")}">
        <style>:root{#{variables.map { |name, value| "#{name}:#{value}" }.join(";")}}</style>
      HTML
    end

    def fallback_layout(body, error)
      %(<!doctype html><html><head>#{head}</head><body class="site"><main>#{body}</main>) +
        (@draft ? %(<p style="padding:1rem;color:#9f1239">The layout has an error: #{ERB::Util.html_escape(error.message)}</p>) : "") + "</body></html>"
    end
end
