require "rails_helper"

RSpec.describe CustomField do
  it_behaves_like "a tenant-scoped model"

  it "derives a key from the label" do
    expect(create(:custom_field, label: "T-shirt size").key).to eq("t_shirt_size")
  end

  it "won't change its key once saved" do
    field = create(:custom_field)
    expect(field.update(key: "renamed")).to be(false)
  end

  it "requires options for select fields" do
    expect(build(:custom_field, field_type: "select", options: [])).not_to be_valid
  end

  describe "#cast" do
    def cast(type, value, options: [])
      build(:custom_field, field_type: type, options:).cast(value)
    end

    it "casts each type to its stored JSON form" do
      expect(cast("text", "  hello ")).to eq("hello")
      expect(cast("number", "1,200")).to eq(1200)
      expect(cast("number", "2.5")).to eq(2.5)
      expect(cast("date", "2026-03-04")).to eq("2026-03-04")
      expect(cast("boolean", "1")).to be(true)
      expect(cast("boolean", "0")).to be(false)
      expect(cast("select", "M", options: %w[ S M ])).to eq("M")
      expect(cast("multi_select", "S; M", options: %w[ S M L ])).to eq(%w[ S M ])
    end

    it "treats blanks as no value" do
      expect(cast("text", " ")).to be_nil
      expect(cast("multi_select", [ "" ], options: %w[ S ])).to be_nil
    end

    it "rejects invalid values" do
      expect { cast("number", "lots") }.to raise_error(CustomField::InvalidValue, "must be a number")
      expect { cast("date", "someday") }.to raise_error(CustomField::InvalidValue)
      expect { cast("select", "XXL", options: %w[ S ]) }.to raise_error(CustomField::InvalidValue, /must be one of/)
      expect { cast("multi_select", "S;Q", options: %w[ S ]) }.to raise_error(CustomField::InvalidValue, /unknown choices: Q/)
    end
  end

  it "removes its values from everyone when deleted" do
    field = create(:custom_field, key: "allergies")
    person = create(:person, custom_field_values: { "allergies" => "Peanuts" })

    field.destroy!
    expect(person.reload.custom_fields).not_to have_key("allergies")
  end

  it "reorders fields in one update" do
    a, b, c = create_list(:custom_field, 3)
    c.reposition(0)
    expect(CustomField.ordered).to eq([ c, a, b ])
  end
end
