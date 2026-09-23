require "rails_helper"

RSpec.describe Permission do
  it "describes every key" do
    expect(described_class.keys).to all(satisfy { |key| described_class.description(key).present? })
  end

  it "fetches known keys given as symbols" do
    expect(described_class.fetch(:manage_users)).to eq("manage_users")
  end

  it "raises for unknown keys" do
    expect { described_class.fetch(:nope) }.to raise_error(Permission::UnknownPermission)
  end
end
