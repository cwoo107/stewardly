# Renders templates in two passes so big sends stay fast:
#
#   1. compile: once per campaign. Section Liquid runs with campaign-wide data (settings,
#      theme, church, upcoming events); per-recipient values stay as {{ person.* }} /
#      {{ links.* }} placeholders; the MJML is compiled to HTML (MRML); links are
#      optionally rewritten for click tracking and an open pixel added.
#   2. personalize: per recipient. Liquid over that HTML with only the person and link
#      drops. No MJML involved.
class EmailTemplate::Renderer
  TRACKABLE_LINK = /href="(https?:\/\/[^"]+)"/

  # base_url: where uploaded images are served from. The editor preview passes the
  # request's own URL; sent email uses the church's public address.
  def initialize(template, church: template.church, base_url: Email::Tracking.base_url(church))
    @template = template
    @church = church
    @base_url = base_url
  end

  # HTML with per-recipient placeholders left in.
  def compile(tracking: nil)
    html = Mjml::MrmlParser.new(nil, mjml).render
    tracking ? tracking.apply(html) : html
  end

  # Image settings become absolute URLs (resized uploads), plus <id>_width / <id>_height.
  # Shared with website pages (Site::Renderer), which also resolve images inside blocks.
  def self.resolve_images(schema, settings, base_url:, background:)
    Array(schema).select { |setting| setting["type"] == "image" }.each do |setting|
      size = setting["size"].to_h
      image = Email::ImageSource.new(settings[setting["id"]], base_url:, width: settings[size["width"]],
        height: settings[size["height"]], fit: settings[size["fit"]], background:).resolve
      settings[setting["id"]] = image&.url
      settings["#{setting["id"]}_width"] = image&.width
      settings["#{setting["id"]}_height"] = image&.height
    end
    settings
  end

  def self.personalize(html, person:, links:)
    Email::Liquid.render(html, "person" => Email::Drops::Person.new(person), "links" => links, "church" => Email::Drops::Church.new(person.church))
  end

  # A complete preview for one person (the editor, and test sends).
  def preview(person)
    links = Email::Drops::Links.new(unsubscribe: "#", preferences: "#")
    self.class.personalize(compile, person:, links:)
  end

  def mjml
    theme = @template.theme_settings
    body = (@template.sections + [ { "key" => "footer", "settings" => {} } ]).map { |section| render_section(section, theme) }.join("\n")

    <<~MJML
      <mjml>
        <mj-head>
          <mj-title>#{ERB::Util.html_escape(@template.subject)}</mj-title>
          #{"<mj-preview>#{ERB::Util.html_escape(@template.preheader)}</mj-preview>" if @template.preheader.present?}
          <mj-attributes>
            <mj-all font-family="#{theme["font_family"]}" />
            <mj-text color="#{theme["text_color"]}" font-size="16px" line-height="1.5" />
          </mj-attributes>
        </mj-head>
        <mj-body background-color="#{theme["background_color"]}" width="600px">
          #{body}
        </mj-body>
      </mjml>
    MJML
  end

  private
    def definitions = @definitions ||= SectionDefinition::Defaults.email_sections.index_by(&:key)

    def render_section(section, theme)
      definition = definitions.fetch(section["key"])
      settings = definition.settings_schema.to_h { |setting| [ setting["id"], nil ] }.merge(definition.default_settings).merge(section["settings"].to_h)
      settings["blocks"] = Array(settings["blocks"]) if definition.blocks_schema
      resolve_images(definition, settings, theme)

      Email::Liquid.render(definition.parsed_liquid,
        "settings" => settings, "theme" => theme, "church" => Email::Drops::Church.new(@church), "events" => events,
        "person" => Email::Drops::Placeholder.new("person"), "links" => Email::Drops::Placeholder.new("links"))
    end

    def resolve_images(definition, settings, theme)
      self.class.resolve_images(definition.settings_schema, settings, base_url: @base_url, background: theme["content_background"])
    end

    def events
      @events ||= EventOccurrence.upcoming.joins(:event).merge(Event.published.where(visibility: "public")).includes(:event).chronological.limit(10)
        .map { |occurrence| Email::Drops::Event.new(occurrence, "#{Email::Tracking.base_url(@church)}/e/#{occurrence.event.slug}") }
    end
end
