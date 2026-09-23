require "rails_helper"

RSpec.describe Email::ImageSource do
  let(:blob) do
    ActiveStorage::Blob.create_and_upload!(io: file_fixture("landscape.png").open, filename: "landscape.png", content_type: "image/png").tap(&:analyze)
  end
  let(:stored) { described_class.stored_value(blob) }

  def resolve(**options) = described_class.new(stored, base_url: "http://grace.localhost:3000", **options).resolve

  def processed_size(result)
    signed_id, variation_key = result.url.match(%r{representations/(?:redirect/)?([^/]+)/([^/]+)/}).captures
    variant = ActiveStorage::Blob.find_signed(signed_id).variant(ActiveStorage::Variation.decode(variation_key)).processed
    variant.image.blob.tap(&:analyze).metadata.values_at("width", "height")
  end

  it "stores uploads by path and builds absolute URLs on the given host when rendering" do
    expect(stored).to start_with("/rails/active_storage/blobs/")
    expect(resolve.url).to start_with("http://grace.localhost:3000/rails/active_storage/representations/")
  end

  it "keeps proportions when only one side is set, capped to the email width" do
    expect(resolve.to_h.slice(:width, :height)).to eq(width: 400, height: 200)
    expect(resolve(width: 200).to_h.slice(:width, :height)).to eq(width: 200, height: 100)
    expect(resolve(height: 150).to_h.slice(:width, :height)).to eq(width: 300, height: 150)
    expect(resolve(width: 9000).width).to eq(described_class::MAX_WIDTH)
  end

  it "renders each fit into exactly the box, at 2× for sharp screens" do
    %w[ fit crop stretch ].each do |fit|
      result = resolve(width: 300, height: 300, fit:)
      expect(result.to_h.slice(:width, :height)).to eq(width: 300, height: 300)
      expect(processed_size(result)).to eq([ 600, 600 ]), "#{fit} should be 600×600"
    end
    center = resolve(width: 300, height: 300, fit: "center")
    expect(processed_size(center)).to eq([ 300, 300 ]) # original pixels, trimmed or padded
  end

  it "passes pasted URLs through with only a size, and ignores anything that isn't http(s)" do
    external = described_class.new("https://cdn.example.com/a.jpg", base_url: "x", width: 200, height: 80).resolve
    expect(external.to_h).to eq(url: "https://cdn.example.com/a.jpg", width: 200, height: 80)
    expect(described_class.new("javascript:alert(1)", base_url: "x").resolve.url).to be_nil
  end

  it "recognises an upload stored with an old absolute URL" do
    old = "http://grace.localhost#{stored}"
    expect(described_class.new(old, base_url: "http://grace.localhost:3055").resolve.url).to start_with("http://grace.localhost:3055/rails/active_storage/representations/")
  end
end
