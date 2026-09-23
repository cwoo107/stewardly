# The built-in sections, installed per church: email (Liquid producing MJML, in
# app/sections/email) and web (Liquid producing HTML, in app/sections/web).
module SectionDefinition::Defaults
  # Bump when a built-in section's schema or Liquid changes; churches pick it up on next use.
  VERSIONS = { "email" => 2, "web" => 1 }.freeze
  VERSION = VERSIONS.fetch("email")

  EMAIL = [
    { key: "header", name: "Header", settings: [
      { "id" => "title", "type" => "text", "label" => "Title" },
      { "id" => "logo_url", "type" => "image", "label" => "Logo", "size" => { "width" => "logo_width" } },
      { "id" => "logo_width", "type" => "number", "label" => "Logo width (px)", "default" => 160 },
      { "id" => "background_color", "type" => "color", "label" => "Background" },
      { "id" => "text_color", "type" => "color", "label" => "Text color", "default" => "#ffffff" }
    ] },
    { key: "text", name: "Text", settings: [
      { "id" => "heading", "type" => "text", "label" => "Heading" },
      { "id" => "body", "type" => "markdown", "label" => "Text", "default" => "Hi {{ person.first_name }},\n\nWrite your message here." },
      { "id" => "align", "type" => "select", "label" => "Alignment", "options" => %w[ left center ], "default" => "left" }
    ] },
    { key: "image", name: "Image", settings: [
      { "id" => "image_url", "type" => "image", "label" => "Image", "size" => { "width" => "width", "height" => "height", "fit" => "fit" } },
      { "id" => "alt", "type" => "text", "label" => "Description (for screen readers)" },
      { "id" => "link", "type" => "url", "label" => "Link (optional)" },
      { "id" => "width", "type" => "number", "label" => "Width (px)", "min" => 1, "max" => Email::ImageSource::MAX_WIDTH,
        "hint" => "Up to #{Email::ImageSource::MAX_WIDTH}. Leave blank for the image's own width." },
      { "id" => "height", "type" => "number", "label" => "Height (px)", "min" => 1, "max" => Email::ImageSource::MAX_HEIGHT,
        "hint" => "Leave blank to keep the image's proportions." },
      { "id" => "fit", "type" => "select", "label" => "Fit", "options" => Email::ImageSource::FITS.keys, "labels" => Email::ImageSource::FITS,
        "default" => "fit", "hint" => "Used when both width and height are set. Best fit shows the whole image; crop fills the box; " \
          "stretch fills it exactly; center keeps the original size. Pasted image links can only be sized, not cropped." },
      { "id" => "align", "type" => "select", "label" => "Alignment", "options" => %w[ center left right ], "default" => "center" }
    ] },
    { key: "button", name: "Button", settings: [
      { "id" => "label", "type" => "text", "label" => "Label", "default" => "Learn more" },
      { "id" => "url", "type" => "url", "label" => "Link" },
      { "id" => "color", "type" => "color", "label" => "Color" },
      { "id" => "align", "type" => "select", "label" => "Alignment", "options" => %w[ center left ], "default" => "center" }
    ] },
    { key: "event_list", name: "Upcoming events", settings: [
      { "id" => "heading", "type" => "text", "label" => "Heading", "default" => "Coming up" },
      { "id" => "count", "type" => "number", "label" => "How many", "default" => 3 }
    ] },
    { key: "links", name: "Links", settings: [ { "id" => "heading", "type" => "text", "label" => "Heading" } ],
      blocks: { "label" => "Link", "settings" => [
        { "id" => "label", "type" => "text", "label" => "Label" }, { "id" => "url", "type" => "url", "label" => "Link" }
      ], "default" => [ { "label" => "Our website", "url" => "" } ] } },
    { key: "divider", name: "Divider", settings: [ { "id" => "color", "type" => "color", "label" => "Color" } ] },
    { key: "footer", name: "Footer", settings: [], system_only: true }
  ].freeze

  # Creates missing built-ins and brings older built-in versions up to date.

  WEB = [
    { key: "hero", name: "Hero", settings: [
      { "id" => "heading", "type" => "text", "label" => "Heading", "default" => "Welcome home" },
      { "id" => "subheading", "type" => "textarea", "label" => "Subheading", "default" => "Join us this Sunday." },
      { "id" => "image_url", "type" => "image", "label" => "Background image", "size" => { "width" => "image_width" } },
      { "id" => "image_width", "type" => "number", "label" => "Image width to load (px)", "default" => 1600, "min" => 400, "max" => 2400, "hint" => "Bigger looks sharper on large screens but loads slower." },
      { "id" => "button_label", "type" => "text", "label" => "Button label", "default" => "Plan a visit" },
      { "id" => "button_url", "type" => "url", "label" => "Button link" },
      { "id" => "align", "type" => "select", "label" => "Alignment", "options" => %w[ center left ], "default" => "center" }
    ] },
    { key: "text", name: "Text", settings: [
      { "id" => "heading", "type" => "text", "label" => "Heading" },
      { "id" => "body", "type" => "markdown", "label" => "Text", "default" => "Tell your story here." },
      { "id" => "align", "type" => "select", "label" => "Alignment", "options" => %w[ left center ], "default" => "left" }
    ] },
    { key: "image", name: "Image", settings: [
      { "id" => "image_url", "type" => "image", "label" => "Image", "size" => { "width" => "width", "height" => "height", "fit" => "fit" } },
      { "id" => "alt", "type" => "text", "label" => "Description (for screen readers)" },
      { "id" => "caption", "type" => "text", "label" => "Caption" },
      { "id" => "width", "type" => "number", "label" => "Width (px)", "min" => 1, "max" => 1200 },
      { "id" => "height", "type" => "number", "label" => "Height (px)", "min" => 1, "max" => 2000 },
      { "id" => "fit", "type" => "select", "label" => "Fit", "options" => Email::ImageSource::FITS.keys, "labels" => Email::ImageSource::FITS, "default" => "fit" }
    ] },
    { key: "image_with_text", name: "Image with text", settings: [
      { "id" => "image_url", "type" => "image", "label" => "Image", "size" => { "width" => "image_width" } },
      { "id" => "image_width", "type" => "number", "label" => "Image width to load (px)", "default" => 800, "min" => 200, "max" => 1600 },
      { "id" => "heading", "type" => "text", "label" => "Heading", "default" => "Who we are" },
      { "id" => "body", "type" => "markdown", "label" => "Text", "default" => "A few sentences about your church." },
      { "id" => "image_side", "type" => "select", "label" => "Image side", "options" => %w[ left right ], "default" => "left" },
      { "id" => "button_label", "type" => "text", "label" => "Button label" },
      { "id" => "button_url", "type" => "url", "label" => "Button link" }
    ] },
    { key: "call_to_action", name: "Call to action", settings: [
      { "id" => "heading", "type" => "text", "label" => "Heading", "default" => "New here?" },
      { "id" => "body", "type" => "textarea", "label" => "Text", "default" => "We'd love to meet you." },
      { "id" => "button_label", "type" => "text", "label" => "Button label", "default" => "Get connected" },
      { "id" => "button_url", "type" => "url", "label" => "Button link" }
    ] },
    { key: "gallery", name: "Gallery", settings: [ { "id" => "heading", "type" => "text", "label" => "Heading" } ],
      blocks: { "label" => "Photo", "settings" => [
        { "id" => "image_url", "type" => "image", "label" => "Photo", "size" => { "width" => "width", "height" => "height", "fit" => "fit" } },
        { "id" => "alt", "type" => "text", "label" => "Description" }
      ], "default" => [] } },
    { key: "faq", name: "Questions and answers", settings: [ { "id" => "heading", "type" => "text", "label" => "Heading", "default" => "Frequently asked questions" } ],
      blocks: { "label" => "Question", "settings" => [
        { "id" => "question", "type" => "text", "label" => "Question" }, { "id" => "answer", "type" => "markdown", "label" => "Answer" }
      ], "default" => [ { "question" => "What should I wear?", "answer" => "Come as you are." } ] } },
    { key: "staff", name: "Staff", settings: [ { "id" => "heading", "type" => "text", "label" => "Heading", "default" => "Our team" } ],
      blocks: { "label" => "Person", "settings" => [
        { "id" => "photo_url", "type" => "image", "label" => "Photo", "size" => { "width" => "photo_width", "height" => "photo_height", "fit" => "photo_fit" } },
        { "id" => "name", "type" => "text", "label" => "Name" }, { "id" => "role", "type" => "text", "label" => "Role" },
        { "id" => "email", "type" => "text", "label" => "Email (optional)" }
      ], "default" => [] } },
    { key: "video", name: "Video", settings: [
      { "id" => "heading", "type" => "text", "label" => "Heading" },
      { "id" => "url", "type" => "url", "label" => "YouTube or Vimeo link", "hint" => "Other video sites aren't supported." }
    ] },
    { key: "service_times", name: "Service times", settings: [
      { "id" => "heading", "type" => "text", "label" => "Heading", "default" => "Join us on Sunday" },
      { "id" => "note", "type" => "textarea", "label" => "Note", "default" => "Kids programs are available at every service." }
    ] },
    { key: "upcoming_events", name: "Upcoming events", settings: [
      { "id" => "heading", "type" => "text", "label" => "Heading", "default" => "What's coming up" },
      { "id" => "count", "type" => "number", "label" => "How many", "default" => 6, "min" => 1, "max" => 24 }
    ] },
    { key: "group_finder", name: "Group finder", settings: [
      { "id" => "heading", "type" => "text", "label" => "Heading", "default" => "Find a group" },
      { "id" => "intro", "type" => "textarea", "label" => "Intro", "default" => "Groups meet throughout the week in homes around the city." },
      { "id" => "group_type", "type" => "select", "label" => "Show", "options" => %w[ all small_group bible_study connection_group other ], "default" => "all" }
    ] },
    { key: "embedded_form", name: "Form", settings: [
      { "id" => "heading", "type" => "text", "label" => "Heading" },
      { "id" => "form", "type" => "form", "label" => "Form", "hint" => "Published public forms only." }
    ] },
    { key: "sermon_links", name: "Sermons", settings: [ { "id" => "heading", "type" => "text", "label" => "Heading", "default" => "Recent sermons" } ],
      blocks: { "label" => "Sermon", "settings" => [
        { "id" => "title", "type" => "text", "label" => "Title" }, { "id" => "speaker", "type" => "text", "label" => "Speaker" },
        { "id" => "date", "type" => "text", "label" => "Date" }, { "id" => "url", "type" => "url", "label" => "Link" }
      ], "default" => [] } },
    { key: "give", name: "Give", settings: [
      { "id" => "heading", "type" => "text", "label" => "Heading", "default" => "Give online" },
      { "id" => "body", "type" => "markdown", "label" => "Text", "default" => "Thank you for your generosity." },
      { "id" => "button_label", "type" => "text", "label" => "Button label", "default" => "Give now" }
    ] },
    { key: "contact", name: "Contact", settings: [
      { "id" => "heading", "type" => "text", "label" => "Heading", "default" => "Get in touch" },
      { "id" => "form", "type" => "form", "label" => "Contact form (optional)" }
    ] }
  ].freeze

  DEFINITIONS = { "email" => EMAIL, "web" => WEB }.freeze

  # Creates missing built-ins and brings older built-in versions up to date, unless a
  # church has customized its copy (advanced mode).
  def self.install!(kind = "email")
    version = VERSIONS.fetch(kind)
    DEFINITIONS.fetch(kind).each_with_index do |definition, position|
      record = SectionDefinition.where(kind:).find_or_initialize_by(key: definition[:key])
      next if record.persisted? && (!record.system? || record.customized? || record.schema["version"] == version)

      schema = { "settings" => definition[:settings], "blocks" => definition[:blocks], "system_only" => definition[:system_only], "version" => version }.compact
      record.update!(name: definition[:name], system: true, position:, schema:,
        liquid: Rails.root.join("app/sections/#{kind}/#{definition[:key]}.liquid").read)
    end
  end

  def self.current?(kind = "email")
    SectionDefinition.where(kind:, system: true).where("schema->>'version' = ? OR customized", VERSIONS.fetch(kind).to_s).count == DEFINITIONS.fetch(kind).size
  end

  # A church's sections of a kind, installed (or updated) the first time they're needed.
  def self.sections(kind)
    install!(kind) unless current?(kind)
    SectionDefinition.where(kind:).ordered
  end

  def self.email_sections = sections("email")
  def self.web_sections = sections("web")

  # The built-in Liquid, for "reset to default" in advanced mode.
  def self.original_liquid(kind, key) = Rails.root.join("app/sections/#{kind}/#{key}.liquid").then { |path| path.exist? ? path.read : nil }
end
