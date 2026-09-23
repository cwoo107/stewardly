require "rails_helper"

RSpec.describe "Form builder" do
  let(:staff) { create(:user, :staff) }

  context "as staff" do
    before { sign_in_as(staff) }

    it "creates a form and opens the builder" do
      post forms_path, params: { form: { name: "Volunteer interest", purpose: "general" } }
      form = Form.find_by!(slug: "volunteer-interest")
      expect(response).to redirect_to(edit_form_path(form))
      get edit_form_path(form)
      expect(response.body).to include("Add a question")
    end

    it "adds, configures, reorders, and removes questions" do
      form = create(:form)
      post form_fields_path(form), params: { field_type: "select" }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      first = form.fields.reload.sole
      expect(first.options).to eq([ "Option 1", "Option 2" ])

      patch form_field_path(form, first), params: { form_field: { label: "Are you new?", options_text: "Yes\nNo", required: "1" } }
      expect(first.reload).to have_attributes(label: "Are you new?", options: %w[ Yes No ], required: true)

      second = form.fields.create!(label: "Why?", field_type: "paragraph")
      patch form_field_path(form, second), params: { form_field: { label: "Why?", visibility_rule: {
        match: "all", conditions: { "0" => { field: first.key, operator: "equals", value: "Yes" } } } } }
      expect(second.reload.visibility_rule).to eq("match" => "all", "conditions" => [ { "field" => first.key, "operator" => "equals", "value" => "Yes" } ])
      expect(response.body).to include("Shown when Are you new? is “Yes”")

      patch move_form_field_path(form, second), params: { position: 0 }
      expect(form.fields.reload.first).to eq(second)

      delete form_field_path(form, second), headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(form.fields.reload).to eq([ first ])
    end

    it "cancels editing back to the question summary" do
      form = create(:form)
      field = create(:form_field, form:, label: "Favorite hymn")
      get form_field_path(form, field)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Favorite hymn", %(id="#{ActionView::RecordIdentifier.dom_id(field, :frame)}"))
    end

    it "adds a blank condition row without saving" do
      form = create(:form)
      create(:form_field, form:, label: "First")
      field = create(:form_field, form: form.reload, label: "Second")

      patch form_field_path(form, field), params: { add_condition: "1", form_field: { label: "Renamed" } }

      expect(response.body).to include("form_field[visibility_rule][conditions][0][field]")
      expect(field.reload.label).to eq("Second")
    end

    it "shows validation errors in the field editor" do
      form = create(:form)
      field = create(:form_field, form:, field_type: "text")
      patch form_field_path(form, field), params: { form_field: { label: "", maps_to: "person.email" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Label can&#39;t be blank", "needs a email field")
    end

    it "publishes, previews, and closes" do
      form = create(:form)
      patch publish_form_path(form)
      follow_redirect!
      expect(response.body).to include("Add at least one field")

      create(:form_field, form:)
      get preview_form_path(form)
      expect(response.body).to include("Preview. Submitting is turned off.")

      patch publish_form_path(form)
      expect(form.reload).to be_published
      patch close_form_path(form)
      expect(form.reload).to be_closed
    end
  end

  it "keeps the builder from people without manage_forms" do
    form = create(:form)
    sign_in_as(create(:user, :care_team))
    get edit_form_path(form)
    expect(response).to have_http_status(:not_found)
    post form_fields_path(form), params: { field_type: "text" }
    expect(response).to have_http_status(:not_found)
  end
end
