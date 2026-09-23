require "rails_helper"

RSpec.describe "Tenant resolution" do
  let(:user) { create(:user, :staff) }

  it "serves a church on its subdomain" do
    on_church(church)
    get new_session_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Sign in to #{church.name}")
  end

  it "returns 404 for an unknown subdomain" do
    host! "nowhere.#{Rails.configuration.x.app_domain}"
    get new_session_path
    expect(response).to have_http_status(:not_found)
  end

  it "does not route reserved subdomains to the church app" do
    host! "www.#{Rails.configuration.x.app_domain}"
    get new_session_path
    expect(response).to have_http_status(:not_found)
  end

  it "rejects a session cookie from another church" do
    sign_in_as(user)
    other_church = create(:church, subdomain: "elsewhere")

    on_church(other_church)
    get root_path
    expect(response).to redirect_to(new_session_url)
  end

  it "only signs in users belonging to the current church" do
    other_church = create(:church, subdomain: "elsewhere")
    on_church(other_church)
    post session_path, params: { email_address: user.email_address, password: "password" }

    expect(response).to redirect_to(new_session_path)
    expect(flash[:alert]).to be_present
  end

  it "runs each request in the church's time zone" do
    church.update!(time_zone: "Central Time (US & Canada)")
    sign_in_as(user)

    travel_to Time.utc(2026, 9, 21, 3, 0) do # still Sep 20 in Chicago
      get root_path
    end

    expect(response.body).to include("September 20, 2026")
    expect(Time.zone.name).to eq("UTC") # restored afterwards
  end

  it "requires authentication for church pages" do
    on_church(church)
    get root_path
    expect(response).to redirect_to(new_session_url)
  end
end
