# The three built-in themes. Each is a layout (app/themes/<key>/layout.liquid) and a
# stylesheet (app/assets/stylesheets/themes/<key>.css) driven by the site's settings,
# which become CSS variables (--site-brand, --site-heading-font, ...).
Site::Theme = Data.define(:key, :name, :description, :defaults)

class Site::Theme
  FONTS = {
    "system" => [ "Clean sans-serif", "ui-sans-serif, system-ui, -apple-system, 'Segoe UI', sans-serif" ],
    "serif" => [ "Classic serif", "Georgia, 'Iowan Old Style', 'Palatino Linotype', serif" ],
    "rounded" => [ "Friendly rounded", "ui-rounded, 'SF Pro Rounded', 'Nunito', system-ui, sans-serif" ],
    "mono" => [ "Typewriter", "ui-monospace, 'SF Mono', Menlo, monospace" ]
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

  def self.all
    [
      new("modern", "Modern", "Bold color bands, big type, rounded cards.",
        { "brand_color" => "#0e7490", "accent_color" => "#f97316", "background_color" => "#ffffff", "surface_color" => "#f1f5f9",
          "text_color" => "#0f172a", "heading_font" => "system", "body_font" => "system", "logo_width" => 140 }),
      new("classic", "Classic", "Warm serif headings, cream background, framed photos.",
        { "brand_color" => "#7c2d12", "accent_color" => "#b45309", "background_color" => "#fffbf5", "surface_color" => "#f5ecdf",
          "text_color" => "#292524", "heading_font" => "serif", "body_font" => "serif", "logo_width" => 160 }),
      new("minimal", "Minimal", "Lots of white space, thin lines, quiet color.",
        { "brand_color" => "#111827", "accent_color" => "#2563eb", "background_color" => "#ffffff", "surface_color" => "#f9fafb",
          "text_color" => "#111827", "heading_font" => "system", "body_font" => "system", "logo_width" => 120 })
    ]
  end

  def self.keys = all.map(&:key)
  def self.fetch(key) = all.find { |theme| theme.key == key } || all.first

  def default_settings = defaults
  def layout = Rails.root.join("app/themes/#{key}/layout.liquid").read
  def stylesheet = "themes/#{key}"
end
