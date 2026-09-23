require "rails_helper"

RSpec.describe EmailTemplate::SectionSettings do
  let(:definitions) { SectionDefinition::Defaults.email_sections.index_by(&:key) }

  it "keeps only schema settings and casts them" do
    settings = described_class.new(definitions["button"], {}).apply({ "label" => "Go", "url" => "javascript:alert(1)", "color" => "red", "align" => "bogus", "extra" => "x" })
    expect(settings).to eq("label" => "Go", "url" => nil, "color" => nil, "align" => "center")
  end

  it "keeps sizes within the schema's limits" do
    settings = described_class.new(definitions["image"], {}).apply({ "width" => "5000", "height" => "0", "fit" => "crop" })
    expect(settings).to include("width" => Email::ImageSource::MAX_WIDTH, "height" => 1, "fit" => "crop")
  end

  it "adds and removes repeatable blocks" do
    links = definitions["links"]
    added = described_class.new(links, {}).apply({ "blocks" => { "0" => { "label" => "A", "url" => "https://a.example" } } }, block_action: "add")
    expect(added["blocks"].size).to eq(2)
    removed = described_class.new(links, added).apply({ "blocks" => { "0" => { "label" => "A" }, "1" => { "label" => "B" } } }, block_action: "remove_0")
    expect(removed["blocks"].map { |block| block["label"] }).to eq([ "B" ])
  end
end
