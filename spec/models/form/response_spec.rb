require "rails_helper"

RSpec.describe Form::Response do
  let(:form) { create(:form, :connect_card) }

  it "casts visible answers and reports errors by field" do
    response = described_class.new(form, { "first_name" => " Ada ", "last_name" => "", "email" => "bad" })
    expect(response).not_to be_valid
    expect(response.errors).to eq("last_name" => "is required", "email" => "isn't a valid email address")
  end

  it "ignores hidden fields, even when a value is sent" do
    response = described_class.new(form, { "first_name" => "Ada", "last_name" => "L", "first_visit" => "0", "heard" => "Online" })
    expect(response).to be_valid
    expect(response.answers).to eq("first_name" => "Ada", "last_name" => "L", "first_visit" => false)
    expect(response.visible_keys).not_to include("heard")
  end

  it "requires conditional fields only when they're shown" do
    response = described_class.new(form, { "first_name" => "Ada", "last_name" => "L", "first_visit" => "1" })
    expect(response.errors).to eq("heard" => "is required")
  end

  it "keeps sensitive answers apart" do
    create(:form_field, form:, key: "notes", field_type: "paragraph", sensitive: true)
    form.fields.reset
    response = described_class.new(form, { "first_name" => "Ada", "last_name" => "L", "notes" => "Private" })
    expect(response.sensitive_answers).to eq("notes" => "Private")
    expect(response.answers).not_to have_key("notes")
  end
end
