require "rails_helper"

RSpec.describe "Church settings" do
  context "as a church admin" do
    let(:admin) { create(:user, :church_admin) }

    before { sign_in_as(admin) }

    it "updates the name and time zone and audits the change" do
      get edit_church_settings_path
      expect(response).to have_http_status(:ok)

      patch church_settings_path, params: { church: { name: "Grace Downtown", time_zone: "Eastern Time (US & Canada)" } }

      expect(response).to redirect_to(edit_church_settings_path)
      expect(church.reload).to have_attributes(name: "Grace Downtown", time_zone: "Eastern Time (US & Canada)")
      expect(AuditEvent.last).to have_attributes(action: "church.settings_updated", actor: admin, ip_address: "127.0.0.1")
    end

    it "cannot change the subdomain here" do
      patch church_settings_path, params: { church: { subdomain: "hijack" } }
      expect(church.reload.subdomain).not_to eq("hijack")
    end

    it "shows validation errors" do
      patch church_settings_path, params: { church: { name: "" } }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  %i[ staff care_team member ].each do |role|
    it "is forbidden to #{role.to_s.humanize.downcase}" do
      sign_in_as(create(:user, role))

      get edit_church_settings_path
      expect(response).to have_http_status(:forbidden)

      patch church_settings_path, params: { church: { name: "Nope" } }
      expect(response).to have_http_status(:forbidden)
      expect(church.reload.name).not_to eq("Nope")
    end
  end
end
