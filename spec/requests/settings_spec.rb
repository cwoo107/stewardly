require "rails_helper"

RSpec.describe "People settings" do
  include ActiveJob::TestHelper

  context "as a church admin" do
    before { sign_in_as(create(:user, :church_admin)) }

    it "manages tags" do
      post tags_path, params: { tag: { name: "Newcomer", color: "green" } }
      tag = Tag.find_by!(name: "Newcomer")
      patch tag_path(tag), params: { tag: { name: "New here" } }
      get tags_path
      expect(response.body).to include("New here")
      delete tag_path(tag)
      expect(Tag.count).to eq(0)
    end

    it "manages and reorders custom fields" do
      post custom_fields_path, params: { custom_field: { label: "Shirt size", field_type: "select", options_text: "S\nM\nL" } }
      field = CustomField.find_by!(key: "shirt_size")
      expect(field.options).to eq(%w[ S M L ])

      other = create(:custom_field)
      patch move_custom_field_path(other), params: { position: 0 }
      expect(response).to have_http_status(:no_content)
      expect(CustomField.ordered.first).to eq(other)

      patch custom_field_path(field), params: { custom_field: { label: "T-shirt", key: "hacked", field_type: "text" } }
      expect(field.reload).to have_attributes(label: "T-shirt", key: "shirt_size", field_type: "select")
    end

    it "manages campuses and geocodes them" do
      expect {
        post campuses_path, params: { campus: { name: "North", address_line1: "9 North Rd", city: "Nashville", postal_code: "37207" } }
      }.to have_enqueued_job(GeocodeJob)
      get campuses_path
      expect(response.body).to include("North")
    end

    it "sets the group coverage radius" do
      patch church_settings_path, params: { church: { group_coverage_miles: 5 } }
      expect(church.reload.group_coverage_miles).to eq(5)
    end
  end

  it "keeps campuses to church admins and tags to people managers" do
    sign_in_as(create(:user, :care_team))
    get tags_path
    expect(response).to have_http_status(:forbidden)
    get campuses_path
    expect(response).to have_http_status(:forbidden)
  end
end
