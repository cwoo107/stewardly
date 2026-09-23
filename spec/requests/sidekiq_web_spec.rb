require "rails_helper"

RSpec.describe "Sidekiq dashboard" do
  it "is hidden from visitors" do
    on_platform
    get "/sidekiq"
    expect(response).to have_http_status(:not_found)
  end

  it "is hidden on church subdomains, even from church admins" do
    sign_in_as(create(:user, :church_admin))
    get "/sidekiq"
    expect(response).to have_http_status(:not_found)
  end

  it "is available to signed-in platform admins" do
    sign_in_as_platform_admin(create(:platform_admin))
    get "/sidekiq"
    expect(response).to have_http_status(:ok)
  end
end
