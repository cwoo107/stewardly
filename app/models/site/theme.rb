# The built-in themes. Each is a layout (app/themes/<key>/layout.liquid) and a
# stylesheet (app/assets/stylesheets/themes/<key>.css) driven by the site's settings,
# which become CSS variables (--site-brand, --site-heading-font, ...). Premium themes
# add settings of their own (a header button, a motto, ...) after the shared ones.
Site::Theme = Data.define(:key, :name, :description, :defaults, :premium, :extra_settings, :home_sections)

class Site::Theme
  # key => [ label, CSS font stack, Google Fonts family (web fonts only) ]
  FONTS = {
    "system" => [ "Clean sans-serif", "ui-sans-serif, system-ui, -apple-system, 'Segoe UI', sans-serif" ],
    "serif" => [ "Classic serif", "Georgia, 'Iowan Old Style', 'Palatino Linotype', serif" ],
    "rounded" => [ "Friendly rounded", "ui-rounded, 'SF Pro Rounded', 'Nunito', system-ui, sans-serif" ],
    "mono" => [ "Typewriter", "ui-monospace, 'SF Mono', Menlo, monospace" ],
    "inter" => [ "Inter", "'Inter', ui-sans-serif, system-ui, sans-serif", "Inter:wght@400;500;600;700" ],
    "montserrat" => [ "Montserrat (bold display)", "'Montserrat', 'Inter', ui-sans-serif, system-ui, sans-serif", "Montserrat:wght@500;600;700;800;900" ],
    "cormorant" => [ "Cormorant Garamond (engraved serif)", "'Cormorant Garamond', Georgia, serif", "Cormorant+Garamond:ital,wght@0,500;0,600;0,700;1,500" ],
    "garamond" => [ "EB Garamond (book serif)", "'EB Garamond', Georgia, serif", "EB+Garamond:ital,wght@0,400;0,500;0,600;1,400" ]
  }.freeze

  SETTINGS = [
    { "id" => "brand_color", "type" => "color", "label" => "Main color" },
    { "id" => "accent_color", "type" => "color", "label" => "Accent color" },
    { "id" => "background_color", "type" => "color", "label" => "Page background" },
    { "id" => "surface_color", "type" => "color", "label" => "Card and band background" },
    { "id" => "text_color", "type" => "color", "label" => "Text" },
    { "id" => "heading_font", "type" => "select", "label" => "Heading font", "options" => FONTS.keys, "labels" => FONTS.transform_values(&:first) },
    { "id" => "body_font", "type" => "select", "label" => "Body font", "options" => FONTS.keys, "labels" => FONTS.transform_values(&:first) },
    { "id" => "logo_url", "type" => "image", "label" => "Logo", "size" => { "width" => "logo_width" } },
    { "id" => "logo_width", "type" => "number", "label" => "Logo width (px)", "min" => 40, "max" => 400 },
    { "id" => "tagline", "type" => "text", "label" => "Tagline" },
    { "id" => "footer_text", "type" => "textarea", "label" => "Footer text" },
    { "id" => "facebook_url", "type" => "url", "label" => "Facebook page" },
    { "id" => "instagram_url", "type" => "url", "label" => "Instagram" },
    { "id" => "youtube_url", "type" => "url", "label" => "YouTube channel" }
  ].freeze

  # The settings "use this theme's colors and fonts" resets. Logo, text, and links are kept.
  LOOK = %w[ brand_color accent_color background_color surface_color text_color heading_font body_font ].freeze

  HEADER_BUTTON = [
    { "id" => "header_button_label", "type" => "text", "label" => "Header button label" },
    { "id" => "header_button_url", "type" => "url", "label" => "Header button link" }
  ].freeze

  def self.all
    [
      build("modern", "Modern", "Bold color bands, big type, rounded cards.",
        { "brand_color" => "#0e7490", "accent_color" => "#f97316", "background_color" => "#ffffff", "surface_color" => "#f1f5f9",
          "text_color" => "#0f172a", "heading_font" => "system", "body_font" => "system", "logo_width" => 140 }),
      build("classic", "Classic", "Warm serif headings, cream background, framed photos.",
        { "brand_color" => "#7c2d12", "accent_color" => "#b45309", "background_color" => "#fffbf5", "surface_color" => "#f5ecdf",
          "text_color" => "#292524", "heading_font" => "serif", "body_font" => "serif", "logo_width" => 160 }),
      build("minimal", "Minimal", "Lots of white space, thin lines, quiet color.",
        { "brand_color" => "#111827", "accent_color" => "#2563eb", "background_color" => "#ffffff", "surface_color" => "#f9fafb",
          "text_color" => "#111827", "heading_font" => "system", "body_font" => "system", "logo_width" => 120 }),
      build("summit", "Summit", "Big-stage energy: full-bleed dark hero under a floating header, heavy uppercase type, a Plan a Visit button, and a Watch Live link.",
        { "brand_color" => "#0a0a0a", "accent_color" => "#f59e0b", "background_color" => "#ffffff", "surface_color" => "#f4f4f5",
          "text_color" => "#0a0a0a", "heading_font" => "montserrat", "body_font" => "inter", "logo_width" => 150 },
        premium: true, extra_settings: HEADER_BUTTON + [
          { "id" => "watch_label", "type" => "text", "label" => "Livestream link label", "hint" => "Like \"Watch live\". Shown with a pulsing dot when the link is set too." },
          { "id" => "watch_url", "type" => "url", "label" => "Livestream link" },
          { "id" => "announcement", "type" => "text", "label" => "Announcement bar", "hint" => "A short line across the top of every page. Leave blank to hide." },
          { "id" => "announcement_url", "type" => "url", "label" => "Announcement link" },
          { "id" => "footer_links_heading", "type" => "text", "label" => "Footer menu heading", "hint" => "Like \"Explore\". Leave blank for none." },
          { "id" => "footer_info_heading", "type" => "text", "label" => "Footer text heading", "hint" => "Like \"Visit us\". Leave blank for none." }
        ], home_sections: [
          [ "hero", { "align" => "left", "button_url" => "/about" } ], [ "service_times", {} ], [ "next_steps", {} ],
          [ "upcoming_events", { "count" => 3 } ], [ "stats", {} ], [ "quote", {} ],
          [ "call_to_action", { "button_label" => "Plan your visit", "button_url" => "/about" } ]
        ]),
      build("geneva", "Geneva", "Reformed and Reformation-era: engraved serif type, parchment and ink, ruled borders, small caps, and a church motto.",
        { "brand_color" => "#1f2a44", "accent_color" => "#8a6d3b", "background_color" => "#fbf8f1", "surface_color" => "#f1ebdd",
          "text_color" => "#1c1917", "heading_font" => "cormorant", "body_font" => "garamond", "logo_width" => 150 },
        premium: true, extra_settings: [
          { "id" => "motto", "type" => "text", "label" => "Motto", "hint" => "Shown above the church name, like \"Post Tenebras Lux\" or \"Soli Deo Gloria\"." },
          { "id" => "confession", "type" => "text", "label" => "Confessional standard", "hint" => "Shown in the footer, like \"Confessing the Westminster Standards\"." },
          { "id" => "denomination", "type" => "text", "label" => "Denomination or presbytery", "hint" => "Shown in the footer, like \"A congregation of the PCA\"." },
          { "id" => "scripture", "type" => "textarea", "label" => "Footer scripture", "hint" => "A verse set large at the top of the footer." },
          { "id" => "closing_line", "type" => "text", "label" => "Closing line", "hint" => "Shown in italics after the copyright, like \"Soli Deo Gloria\"." }
        ], home_sections: [
          [ "hero", { "button_url" => "/about" } ], [ "text", { "heading" => "Who we are", "body" => "Tell visitors about your church: its history, its worship, and what it confesses." } ],
          [ "service_times", {} ], [ "quote", {} ], [ "sermon_links", {} ], [ "upcoming_events", { "count" => 3 } ],
          [ "call_to_action", { "button_label" => "Plan your visit", "button_url" => "/about" } ]
        ]),
      build("clarity", "Clarity", "Clean and modern: crisp Inter type, soft gray neutrals, bordered cards, and lots of breathing room.",
        { "brand_color" => "#171717", "accent_color" => "#06b6d4", "background_color" => "#ffffff", "surface_color" => "#f5f5f5",
          "text_color" => "#171717", "heading_font" => "inter", "body_font" => "inter", "logo_width" => 130 },
        premium: true, extra_settings: HEADER_BUTTON + [
          { "id" => "secondary_button_label", "type" => "text", "label" => "Second header link label", "hint" => "An outlined button beside the main one, like \"Give\"." },
          { "id" => "secondary_button_url", "type" => "url", "label" => "Second header link" }
        ], home_sections: [
          [ "hero", { "align" => "left", "button_url" => "/about" } ], [ "next_steps", {} ], [ "service_times", {} ], [ "stats", {} ],
          [ "upcoming_events", { "count" => 3 } ], [ "faq", {} ], [ "call_to_action", { "button_label" => "Plan your visit", "button_url" => "/about" } ]
        ])
    ]
  end

  def self.keys = all.map(&:key)
  def self.fetch(key) = all.find { |theme| theme.key == key } || all.first

  # Google Fonts stylesheet for the web fonts among these font keys, or nil.
  def self.font_stylesheet_url(*font_keys)
    families = font_keys.uniq.filter_map { |font_key| FONTS.dig(font_key, 2) }
    "https://fonts.googleapis.com/css2?#{families.map { |family| "family=#{family}" }.join("&")}&display=swap" if families.any?
  end

  def self.build(key, name, description, defaults, premium: false, extra_settings: [], home_sections: [])
    new(key:, name:, description:, defaults:, premium:, extra_settings:, home_sections:)
  end

  def default_settings = defaults
  def settings_schema = SETTINGS + extra_settings
  def layout = Rails.root.join("app/themes/#{key}/layout.liquid").read

  # The theme's own Liquid for a built-in section (app/themes/<key>/sections/<section>.liquid), or nil.
  def section_liquid(section_key)
    path = Rails.root.join("app/themes/#{key}/sections/#{section_key}.liquid")
    path.read if section_key.to_s.match?(/\A[a-z][a-z0-9_]*\z/) && path.exist?
  end
  def stylesheet = "themes/#{key}"
end
