require "rails_helper"

RSpec.describe Site::Renderer do
  let(:site) { Site.current }
  let(:page) { site.pages.create!(title: "Test", slug: "test") }

  def render(draft: true) = described_class.new(site, page, draft:).render

  it "renders sections inside the theme layout with the site's colors" do
    site.update!(theme_settings: { "brand_color" => "#123456" })
    entry = page.add_section!("hero")
    page.update_section!(entry["id"], entry["settings"].merge("heading" => "Hello <script>alert(1)</script>"))
    html = render.html
    expect(html).to include("--site-brand:#123456", "Hello &lt;script&gt;", "site-modern", "themes/modern")
    expect(html).not_to include("<script>alert")
  end

  it "renders every starter page in each premium theme, with its web fonts and settings" do
    Site::Theme.all.select(&:premium).each do |theme|
      site.update!(theme_key: theme.key, theme_settings: {})
      site.pages.each do |starter|
        result = described_class.new(site, starter, draft: true).render
        expect(result.errors).to be_empty, "#{theme.key} #{starter.title}: #{result.errors.join(", ")}"
        expect(result.html).to include("site-#{theme.key}", "themes/#{theme.key}", "fonts.googleapis.com/css2?family=")
      end
    end

    site.update!(theme_key: "summit", theme_settings: { "watch_url" => "https://youtube.com/@grace", "watch_label" => "Watch live", "announcement" => "Easter services",
      "header_button_label" => "Plan a visit", "header_button_url" => "/about" })
    expect(render.html).to include("Plan a visit", "https://youtube.com/@grace", "Watch live", "Easter services")
    site.update!(theme_key: "geneva", theme_settings: { "motto" => "Soli Deo Gloria", "confession" => "Confessing the Westminster Standards", "scripture" => "Isaiah 40:8" })
    expect(render.html).to include("Soli Deo Gloria", "Confessing the Westminster Standards", "Isaiah 40:8")
    site.update!(theme_key: "clarity", theme_settings: { "secondary_button_label" => "Give", "secondary_button_url" => "/give" })
    expect(render.html).to include("clarity-button-outline").and include(%(href="/give"))
  end

  it "shows no text of its own in a premium theme: with every setting blank, only the church's name is left" do
    words = ->(text) { text.to_s.scan(/\p{L}+/).map(&:downcase) }
    allowed = words.("#{site.name} #{church.name}").to_set
    blank_sections = SectionDefinition::Defaults.web_sections.map do |definition|
      # What a form saves when every field is left empty.
      settings = definition.settings_schema.to_h { |setting| [ setting["id"], { "number" => nil, "select" => setting["default"] }.fetch(setting["type"], "") ] }
      settings["blocks"] = [] if definition.blocks_schema
      { "id" => definition.key, "key" => definition.key, "settings" => settings }
    end
    page.update!(draft_sections: blank_sections)

    Site::Theme.all.select(&:premium).each do |theme|
      site.update!(theme_key: theme.key, theme_settings: {})
      body = Nokogiri::HTML(render.html).at("body").tap { |node| node.css("script, style").remove }
      expect(words.(body.text).to_set - allowed).to be_empty, "#{theme.name} shows its own text: #{(words.(body.text).to_set - allowed).to_a.join(", ")}"
    end
  end

  it "uses a theme's own design for a built-in section until the church edits that section's code" do
    theme = SimpleDelegator.new(site.theme)
    def theme.section_liquid(key) = (%(<p class="theme-text">{{ settings.heading | escape }}</p>) if key == "text")
    allow(site).to receive(:theme).and_return(theme)
    entry = page.add_section!("text")
    page.update_section!(entry["id"], entry["settings"].merge("heading" => "Our story"))
    expect(render.html).to include(%(<p class="theme-text">Our story</p>))

    SectionDefinition.kind_web.find_by!(key: "text").update!(liquid: %(<p class="church-text">{{ settings.heading }}</p>), customized: true)
    html = render.html
    expect(html).to include(%(<p class="church-text">Our story</p>))
    expect(html).not_to include("theme-text")
  end

  it "loads no web fonts for system fonts" do
    expect(render.html).not_to include("fonts.googleapis.com")
  end

  it "shows only public data: published public events, active groups (town only), service times" do
    create(:worship_service, name: "Sunday Worship", day_of_week: 0, start_time: "10:30")
    group = create(:group, name: "Tuesday Group", city: "Springfield", address_line1: "12 Secret Lane")
    create(:group, name: "Old Group", active: false)
    %w[ service_times group_finder ].each { |key| page.add_section!(key) }
    html = render.html
    expect(html).to include("Sunday 10:30 AM", "Tuesday Group", "Springfield", "/me/groups/#{group.id}")
    expect(html).not_to include("Secret Lane", "Old Group")
  end

  it "embeds published public forms with their spam protection, and nothing else" do
    Form::Starters.install!
    Form.find_by!(slug: "connect").publish!
    entry = page.add_section!("embedded_form")
    page.update_section!(entry["id"], entry["settings"].merge("form" => "connect"))
    html = render.html
    expect(html).to include('action="/f/connect"', 'name="website"', 'name="started_at"', "First name")

    page.update_section!(entry["id"], entry["settings"].merge("form" => "prayer")) # a draft form
    expect(render.html).not_to include("/f/prayer")
  end

  it "embeds YouTube and Vimeo only" do
    expect(described_class.video_embed_url("https://www.youtube.com/watch?v=dQw4w9WgXcQ")).to eq("https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ")
    expect(described_class.video_embed_url("https://vimeo.com/76979871")).to eq("https://player.vimeo.com/video/76979871")
    expect(described_class.video_embed_url("https://evil.example/embed")).to be_nil
    expect(described_class.video_embed_url("javascript:alert(1)")).to be_nil
  end

  it "leaves a broken section out for visitors but explains it in the draft preview" do
    definition = SectionDefinition.create!(kind: "web", key: "broken", name: "Broken", liquid: "{{ settings.nope | escape }}", schema: { "settings" => [] })
    page.update!(draft_sections: [ { "id" => "b", "key" => definition.key, "settings" => {} } ], published_sections: [ { "id" => "b", "key" => definition.key, "settings" => {} } ])
    draft = render
    expect(draft.errors.first).to include("Broken")
    expect(draft.html).to include("Broken:")
    expect(render(draft: false).html).not_to include("Broken:")
  end

  it "can't reach models: only drops, and Liquid can't loop forever" do
    SectionDefinition.create!(kind: "web", key: "sneaky", name: "Sneaky", liquid: "{{ church.id }}{{ church.destroy }}", schema: { "settings" => [] })
    page.update!(draft_sections: [ { "id" => "s", "key" => "sneaky", "settings" => {} } ])
    expect(render.errors.first).to include("undefined method")
    expect(Church.exists?(church.id)).to be(true)

    SectionDefinition.create!(kind: "web", key: "loop", name: "Loop", liquid: "{% for i in (1..100000) %}{% for j in (1..100000) %}x{% endfor %}{% endfor %}", schema: { "settings" => [] })
    page.update!(draft_sections: [ { "id" => "l", "key" => "loop", "settings" => {} } ])
    expect(render.errors.first).to match(/limit/i)
  end
end
