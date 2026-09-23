# Ready-made templates every church starts with.
module EmailTemplate::Starters
  TEMPLATES = {
    "Weekly newsletter" => [ [ "header", { "title" => "This week" } ], [ "text", {} ], [ "event_list", {} ], [ "button", { "label" => "Give online" } ] ],
    "Event invitation" => [ [ "header", { "title" => "You're invited" } ], [ "image", {} ], [ "text", { "heading" => "Join us" } ], [ "button", { "label" => "Register" } ] ],
    "Announcement" => [ [ "text", { "heading" => "An update from church" } ], [ "divider", {} ], [ "links", {} ] ]
  }.freeze

  def self.install!
    TEMPLATES.each do |name, sections|
      next if EmailTemplate.exists?(name:)

      template = EmailTemplate.create!(name:, subject: name)
      sections.each { |key, settings| entry = template.add_section!(key); template.update_section!(entry["id"], entry["settings"].merge(settings)) }
    end
  end
end
