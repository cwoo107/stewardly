# The pages every new site starts with (drafts until someone publishes them).
module Site::Starters
  PAGES = [
    { title: "Home", slug: "", kind: "home", sections: [
      [ "hero", { "heading" => "Welcome home", "subheading" => "A church for the whole family, in the heart of the city.", "button_url" => "/about" } ],
      [ "service_times", {} ], [ "upcoming_events", { "count" => 3 } ],
      [ "call_to_action", { "heading" => "New here?", "button_label" => "Plan your visit", "button_url" => "/about" } ]
    ] },
    { title: "About", slug: "about", kind: "about", sections: [
      [ "image_with_text", {} ], [ "text", { "heading" => "What we believe", "body" => "Share your beliefs and values here." } ],
      [ "staff", {} ], [ "faq", {} ]
    ] },
    { title: "Events", slug: "events", kind: "events", sections: [ [ "upcoming_events", { "heading" => "Events", "count" => 12 } ] ] },
    { title: "Groups", slug: "groups", kind: "groups", sections: [ [ "group_finder", {} ] ] },
    { title: "Give", slug: "give", kind: "give", sections: [ [ "give", {} ] ] },
    { title: "Contact", slug: "contact", kind: "contact", sections: [ [ "contact", { "form" => "connect" } ] ] }
  ].freeze

  def self.install!(site)
    SectionDefinition::Defaults.web_sections
    PAGES.each_with_index do |definition, position|
      page = site.pages.create!(title: definition[:title], slug: definition[:slug], kind: definition[:kind], position:)
      definition[:sections].each do |key, settings|
        entry = page.add_section!(key)
        page.update_section!(entry["id"], entry["settings"].merge(settings))
      end
    end
  end
end
