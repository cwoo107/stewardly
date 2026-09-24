require "rails_helper"

RSpec.describe "Church logo" do
  before { sign_in_as(create(:user, :church_admin)) }

  it "replaces the default mark in the app and on the website, and can be removed" do
    get root_path
    expect(response.body).to include("fill-cyan-500")

    patch church_settings_path, params: { church: { name: church.name, logo: fixture_file_upload("landscape.png", "image/png") } }
    expect(church.reload.logo).to be_attached
    get root_path
    expect(response.body).to include("#{church.name} logo").and include("/rails/active_storage/representations/")
    expect(response.body).not_to include("fill-cyan-500")

    site = Site.current
    home = site.home_page
    html = Site::Renderer.new(site, home, draft: true).render.html
    expect(html).to include("/rails/active_storage/representations/")

    patch church_settings_path, params: { church: { name: church.name, remove_logo: "1" } }
    perform_enqueued_jobs if respond_to?(:perform_enqueued_jobs)
    expect(church.reload.logo).not_to be_attached
  end

  it "only takes small images" do
    patch church_settings_path, params: { church: { name: church.name, logo: fixture_file_upload("ollama/chat.json", "application/json") } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("must be a PNG, JPEG, or WebP image")
  end
end
