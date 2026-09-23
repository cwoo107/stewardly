require "rails_helper"

RSpec.describe FormField do
  it_behaves_like "a tenant-scoped model"

  let(:form) { create(:form) }

  def field(type, **attributes) = build(:form_field, form:, field_type: type, **attributes)

  it "derives unique keys from labels" do
    first = create(:form_field, form:, label: "T-shirt size")
    second = create(:form_field, form: form.reload, label: "T-shirt size")
    expect([ first.key, second.key ]).to eq(%w[ t_shirt_size t_shirt_size_2 ])
  end

  it "keeps its key once created" do
    record = create(:form_field, form:)
    expect(record.update(key: "renamed")).to be(false)
  end

  it "appends new fields to the end of the form" do
    a = create(:form_field, form:)
    b = create(:form_field, form:)
    b.reposition(0)
    expect(form.fields.reload).to eq([ b, a ])
  end

  describe "#cast_answer" do
    it "casts each type" do
      expect(field("text").cast_answer("  hi ")).to eq("hi")
      expect(field("email").cast_answer(" A@Example.com ")).to eq("a@example.com")
      expect(field("phone").cast_answer("(615) 555-0100")).to eq("(615) 555-0100")
      expect(field("number").cast_answer("1,200")).to eq(1200)
      expect(field("date").cast_answer("2026-03-04")).to eq("2026-03-04")
      expect(field("select", options: %w[ A B ]).cast_answer("B")).to eq("B")
      expect(field("multi_select", options: %w[ A B ]).cast_answer([ "", "A" ])).to eq(%w[ A ])
      expect(field("checkbox").cast_answer("1")).to be(true)
      expect(field("checkbox").cast_answer("0")).to be(false)
      expect(field("address").cast_answer({ "line1" => "1 Elm", "postal_code" => "37203" })).to eq("line1" => "1 Elm", "postal_code" => "37203")
    end

    it "returns nil for blank optional answers" do
      %w[ text email number date select ].each { |type| expect(field(type, options: %w[ A ]).cast_answer("")).to be_nil }
      expect(field("address").cast_answer({})).to be_nil
    end

    it "enforces required answers, including ticking a required checkbox" do
      expect { field("text", required: true).cast_answer(" ") }.to raise_error(FormField::InvalidAnswer, "is required")
      expect { field("checkbox", required: true).cast_answer("0") }.to raise_error(FormField::InvalidAnswer, "is required")
      expect { field("multi_select", required: true, options: %w[ A ]).cast_answer([ "" ]) }.to raise_error(FormField::InvalidAnswer)
    end

    it "rejects invalid answers" do
      expect { field("email").cast_answer("nope") }.to raise_error(FormField::InvalidAnswer, /email/)
      expect { field("phone").cast_answer("12") }.to raise_error(FormField::InvalidAnswer, /phone/)
      expect { field("number").cast_answer("lots") }.to raise_error(FormField::InvalidAnswer)
      expect { field("date").cast_answer("someday") }.to raise_error(FormField::InvalidAnswer)
      expect { field("select", options: %w[ A ]).cast_answer("Z") }.to raise_error(FormField::InvalidAnswer)
      expect { field("multi_select", options: %w[ A ]).cast_answer([ "Z" ]) }.to raise_error(FormField::InvalidAnswer)
      expect { field("text").cast_answer("x" * 256) }.to raise_error(FormField::InvalidAnswer, /too long/)
      expect { field("address").cast_answer({ "city" => "Nashville" }) }.to raise_error(FormField::InvalidAnswer, /street/)
    end

    it "accepts images and PDFs under 10 MB only" do
      pdf = Rack::Test::UploadedFile.new(StringIO.new("%PDF-1.4 test"), "application/pdf", original_filename: "letter.pdf")
      script = Rack::Test::UploadedFile.new(StringIO.new("#!/bin/sh"), "text/plain", original_filename: "run.sh")
      expect(field("file").cast_answer(pdf)).to eq(pdf)
      expect { field("file").cast_answer(script) }.to raise_error(FormField::InvalidAnswer, /image or PDF/)
    end
  end

  it "produces the values show/hide rules see" do
    expect(field("checkbox").rule_value("1")).to eq("true")
    expect(field("checkbox").rule_value("0")).to eq("")
    expect(field("multi_select").rule_value([ "", " A " ])).to eq(%w[ A ])
    expect(field("address").rule_value({ "city" => "Nashville" })).to eq("filled")
    expect(field("text").rule_value(nil)).to eq("")
  end

  describe "mapping" do
    it "only allows destinations that suit the field type" do
      expect(field("email", maps_to: "person.email")).to be_valid
      expect(field("text", maps_to: "person.email")).not_to be_valid
      expect(field("text", maps_to: "person.shoe_size")).not_to be_valid
      expect(field("address", maps_to: "household.address")).to be_valid
    end

    it "offers prayer destinations only on prayer forms, and marks the request sensitive" do
      expect(field("paragraph", maps_to: "prayer_request.body")).not_to be_valid

      prayer_field = build(:form_field, form: create(:form, :prayer), field_type: "paragraph", maps_to: "prayer_request.body")
      expect(prayer_field).to be_valid
      expect(prayer_field.sensitive).to be(true)
    end

    it "maps to custom fields of a compatible type" do
      create(:custom_field, :select, key: "size")
      expect(field("select", options: %w[ S ], maps_to: "person.custom.size")).to be_valid
      expect(field("date", maps_to: "person.custom.size")).not_to be_valid
    end

    it "uses each destination once per form" do
      create(:form_field, form:, field_type: "email", maps_to: "person.email")
      expect(field("email", maps_to: "person.email")).not_to be_valid
    end
  end

  it "validates its show/hide rule" do
    create(:form_field, form:, key: "first_visit", field_type: "checkbox")
    form.fields.reset
    expect(field("text", visibility_rule: { conditions: [ { field: "first_visit", operator: "filled" } ] })).to be_valid
    expect(field("text", visibility_rule: { conditions: [ { field: "missing", operator: "filled" } ] })).not_to be_valid
    expect(field("text", visibility_rule: { conditions: [ { field: "first_visit", operator: "equals", value: "" } ] })).not_to be_valid
  end
end
