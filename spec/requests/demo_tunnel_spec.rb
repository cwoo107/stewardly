require "rails_helper"
require Rails.root.join("lib/middleware/demo_tunnel_guard")

# bin/demo's tunnel mapping (development only; switched on here by stubbing).
RSpec.describe "Demo tunnels" do
  let(:app_host) { "calm-lake.trycloudflare.com" }
  let(:site_host) { "quiet-hill.trycloudflare.com" }

  before do
    allow(DemoTunnel).to receive(:enabled?).and_return(true)
    allow(ENV).to receive(:[]).and_call_original
    { "DEMO_CHURCH" => church.subdomain, "DEMO_APP_HOST" => app_host, "DEMO_SITE_HOST" => site_host }.each { |key, value| allow(ENV).to receive(:[]).with(key).and_return(value) }
  end

  it "serves the church's app on the app tunnel, with https links, redirects, and email URLs" do
    user = create(:user, :church_admin)
    host! app_host
    https!
    post session_path, params: { email_address: user.email_address, password: "password" }
    expect(response).to redirect_to("https://#{app_host}/")
    get root_path
    expect(response.body).to include("Welcome")
    expect(Email::Tracking.base_url(church)).to eq("https://#{app_host}")
  end

  it "serves the church's website on the site tunnel" do
    site = Site.current
    site.update!(published: true)
    site.home_page.publish!
    host! site_host
    get "/"
    expect(response.body).to include("Welcome home")
    expect(site.reload.base_url).to eq("https://#{site_host}")
  end

  it "hides developer tools and detailed errors from tunnel viewers, but keeps images" do
    inner = ->(env) { [ 200, {}, [ env["action_dispatch.show_detailed_exceptions"].inspect ] ] }
    guard = DemoTunnelGuard.new(inner)
    expect(guard.call("HTTP_HOST" => app_host, "PATH_INFO" => "/rails/mailers").first).to eq(404)
    expect(guard.call("HTTP_HOST" => site_host, "PATH_INFO" => "/rails/info/routes").first).to eq(404)
    expect(guard.call("HTTP_HOST" => site_host, "PATH_INFO" => "/rails/active_storage/blobs/x").first).to eq(200)
    expect(guard.call("HTTP_HOST" => app_host, "PATH_INFO" => "/people").last).to eq([ "false" ])
    expect(guard.call("HTTP_HOST" => "grace.localhost", "PATH_INFO" => "/rails/mailers").last).to eq([ "nil" ])
  end
end
