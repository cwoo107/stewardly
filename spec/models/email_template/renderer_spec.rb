require "rails_helper"

RSpec.describe EmailTemplate::Renderer do
  let(:template) { create(:email_template) }
  let(:person) { create(:person, first_name: "Ana", nickname: nil) }

  before do
    church.update!(mailing_address: "1 Church St")
    %w[ header text button ].each { |key| template.add_section!(key) }
    template.update_section!(template.sections.second["id"], { "body" => "Hi {{ person.first_name }}, **welcome**. <script>alert(1)</script>" })
  end

  it "compiles once with per-recipient placeholders left in, then personalizes" do
    html = described_class.new(template).compile
    expect(html).to include("{{ person.first_name }}", "{{ links.unsubscribe }}", "{{ links.preferences }}", "1 Church St")
    expect(html).not_to include("<mj-")

    links = Email::Drops::Links.new(unsubscribe: "https://x/u/1", preferences: "https://x/p/1")
    personal = described_class.personalize(html, person:, links:)
    expect(personal).to include("Hi Ana", "<strong>welcome</strong>", "https://x/u/1")
    expect(personal).not_to include("<script>")
  end

  it "rewrites links for tracking and adds an open pixel" do
    template.update_section!(template.sections.third["id"], { "label" => "Give", "url" => "https://give.example.com/?a=1&b=2" })
    html = described_class.new(template).compile(tracking: Email::Tracking.new(church))
    signed = html[%r{/t/c/\{\{ links.token \}\}/([^"]+)"}, 1]
    expect(Email::Tracking.target_for(signed)).to eq("https://give.example.com/?a=1&b=2")
    expect(html).to include("/t/o/{{ links.token }}.gif")
  end

  it "runs Liquid strictly: unknown variables and filters raise instead of rendering blank" do
    expect { Email::Liquid.render("{{ nope }}", {}) }.to raise_error(Liquid::UndefinedVariable)
    expect { Email::Liquid.render("{{ 'a' | nope }}", {}) }.to raise_error(Liquid::UndefinedFilter)
    expect { Email::Liquid.parse("{% if %}") }.to raise_error(Liquid::SyntaxError)
  end

  it "shows event times in the church's time zone, even when compiled outside a request (a job)" do
    church.update!(time_zone: "Central Time (US & Canada)")
    event = create(:event, title: "Newcomer lunch")
    create(:event_occurrence, event:, starts_at: Time.utc(2026, 10, 4, 17, 30), ends_at: Time.utc(2026, 10, 4, 19))
    template.add_section!("event_list")
    html = Time.use_zone("UTC") { described_class.new(template.reload).compile }
    expect(html).to include("12:30 PM")
    expect(html).not_to include("5:30 PM")
  end

    it "refuses to add a second footer" do
    expect { template.add_section!("footer") }.to raise_error(ArgumentError)
  end
end
