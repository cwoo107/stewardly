require "rails_helper"

RSpec.describe FormSubmission::Processing do
  let(:connect_form) { create(:form, :connect_card) }

  def submit(answers, form: connect_form, user: nil)
    response = Form::Response.new(form, answers)
    raise "invalid: #{response.errors}" unless response.valid?

    FormSubmission.build_from(form, response, user:).tap(&:save!)
  end

  def process(submission) = described_class.new(submission).process!.then { submission.reload }

  it "creates a guest for a new name and logs a touchpoint" do
    submission = process(submit({ "first_name" => "Ada", "last_name" => "Lovelace", "email" => "ada@example.com" }))

    person = submission.person
    expect(person).to have_attributes(first_name: "Ada", email: "ada@example.com", membership_status: "guest")
    expect(person.touchpoints.sole).to have_attributes(kind: "form_submission", subject: submission)
    expect(submission).to be_processed
  end

  it "links an anonymous submission by email but only fills blanks" do
    existing = create(:person, first_name: "Ada", last_name: "Lovelace", email: "ada@example.com", phone: nil)
    create(:form_field, form: connect_form, key: "phone", field_type: "phone", maps_to: "person.phone")
    connect_form.fields.reset

    submission = process(submit({ "first_name" => "Hacker", "last_name" => "Person", "email" => "ADA@example.com", "phone" => "615-555-0100" }))

    expect(submission.person).to eq(existing)
    expect(existing.reload).to have_attributes(first_name: "Ada", last_name: "Lovelace", phone: "615-555-0100")
  end

  it "updates a signed-in submitter's own record" do
    user = create(:user, person: create(:person, first_name: "Old", last_name: "Name"))
    submission = process(submit({ "first_name" => "New", "last_name" => "Name", "email" => "someone@else.com" }, user:))
    expect(submission.person).to eq(user.person)
    expect(user.person.reload.first_name).to eq("New")
  end

  it "leaves the submission unlinked without a name or email match" do
    form = create(:form, :published)
    expect(process(submit({ "name" => "Just a name" }, form:)).person).to be_nil
  end

  it "creates a household from a mapped address, and never overwrites one on file anonymously" do
    create(:form_field, form: connect_form, key: "address", field_type: "address", maps_to: "household.address")
    connect_form.fields.reset
    address = { "line1" => "1 Elm St", "city" => "Nashville", "postal_code" => "37203" }
    answers = { "first_name" => "Ada", "last_name" => "Lovelace", "email" => "ada@example.com", "address" => address }

    person = process(submit(answers)).person
    expect(person.household).to have_attributes(name: "The Lovelace household", address_line1: "1 Elm St", postal_code: "37203")

    expect(process(submit(answers.merge("address" => address.merge("line1" => "2 Pine")))).person).to eq(person)
    expect(person.household.reload.address_line1).to eq("1 Elm St")
  end

  it "maps to custom fields, skipping values that don't fit" do
    create(:custom_field, :select, key: "size", options: %w[ S M ])
    create(:form_field, form: connect_form, key: "size", field_type: "select", options: %w[ S M XL ], maps_to: "person.custom.size")
    connect_form.fields.reset

    expect(process(submit({ "first_name" => "A", "last_name" => "B", "size" => "M" })).person.custom_fields).to eq("size" => "M")
    expect(process(submit({ "first_name" => "C", "last_name" => "D", "size" => "XL" })).person.custom_fields).to eq({})
  end

  describe "prayer forms" do
    let(:prayer_form) do
      create(:form, :prayer).tap do |form|
        form.fields.create!(key: "first_name", label: "First", field_type: "text", maps_to: "person.first_name")
        form.fields.create!(key: "last_name", label: "Last", field_type: "text", maps_to: "person.last_name")
        form.fields.create!(key: "request", label: "Request", field_type: "paragraph", required: true, maps_to: "prayer_request.body")
        form.fields.create!(key: "share", label: "Share", field_type: "checkbox", maps_to: "prayer_request.share_with_prayer_team")
        connect_form.fields.reset
        form.publish!
      end
    end

    it "creates a private prayer request, visible to the prayer team only when the submitter agrees" do
      private_one = process(submit({ "first_name" => "Ruth", "last_name" => "Ames", "request" => "Surgery Tuesday" }, form: prayer_form))
      shared_one = process(submit({ "first_name" => "Ruth", "last_name" => "Ames", "request" => "New job", "share" => "1" }, form: prayer_form))

      expect(private_one.prayer_request).to have_attributes(body: "Surgery Tuesday", source: "form", visibility: "pastoral_staff", person: private_one.person)
      expect(shared_one.prayer_request.visibility).to eq("prayer_team")
      expect(private_one.person.touchpoints.first).to be_sensitive
    end

    it "keeps anonymous requests without a person" do
      submission = process(submit({ "request" => "Please pray" }, form: prayer_form))
      expect(submission.prayer_request).to have_attributes(person: nil, requester_name: "Anonymous")
    end
  end

  it "does nothing the second time" do
    submission = submit({ "first_name" => "Ada", "last_name" => "Lovelace" })
    described_class.new(submission).process!
    expect { described_class.new(submission.reload).process! }.not_to change(Touchpoint, :count)
  end
end
