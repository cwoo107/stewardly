# Ready-made draft forms every church starts with: a connect card and a prayer request form.
module Form::Starters
  DEFINITIONS = [
    {
      name: "Connect card", slug: "connect", purpose: "general",
      description: "We'd love to get to know you.",
      confirmation_message: "Thanks for connecting! Someone from our team will be in touch.",
      fields: [
        { key: "first_name", label: "First name", field_type: "text", required: true, maps_to: "person.first_name" },
        { key: "last_name", label: "Last name", field_type: "text", required: true, maps_to: "person.last_name" },
        { key: "email", label: "Email", field_type: "email", required: true, maps_to: "person.email" },
        { key: "phone", label: "Phone", field_type: "phone", maps_to: "person.phone" },
        { key: "first_visit", label: "This is my first visit", field_type: "checkbox" },
        { key: "heard_about_us", label: "How did you hear about us?", field_type: "select",
          options: [ "A friend", "Online search", "Social media", "Drove by", "Other" ],
          visibility_rule: { match: "all", conditions: [ { field: "first_visit", operator: "filled" } ] } },
        { key: "interests", label: "I'd like to know more about", field_type: "multi_select",
          options: [ "Joining a group", "Serving", "Baptism", "Talking with a pastor" ] },
        { key: "comments", label: "Anything else?", field_type: "paragraph" }
      ]
    },
    {
      name: "Prayer request", slug: "prayer", purpose: "prayer_request",
      description: "Share a request and we'll pray with you. Requests are kept private.",
      confirmation_message: "Thank you. We're praying with you.",
      fields: [
        { key: "first_name", label: "First name", field_type: "text", maps_to: "person.first_name" },
        { key: "last_name", label: "Last name", field_type: "text", maps_to: "person.last_name" },
        { key: "email", label: "Email", field_type: "email", maps_to: "person.email", help_text: "Optional, so we can follow up." },
        { key: "request", label: "How can we pray for you?", field_type: "paragraph", required: true, maps_to: "prayer_request.body" },
        { key: "share", label: "It's OK to share this with our prayer team", field_type: "checkbox",
          maps_to: "prayer_request.share_with_prayer_team" }
      ]
    }
  ].freeze

  def self.install!
    DEFINITIONS.each do |definition|
      next if Form.exists?(slug: definition[:slug])

      form = Form.create!(definition.except(:fields))
      definition[:fields].each { |field| form.fields.create!(field) }
    end
  end
end
