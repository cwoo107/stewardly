module RequestAuthenticationHelpers
  # Points requests at the church's subdomain, e.g. grace.localhost.
  def on_church(church)
    host! church.host
  end

  def sign_in_as(user, password: "password")
    on_church(user.church)
    post session_path, params: { email_address: user.email_address, password: }
    expect(response).to redirect_to(user.admin_area? ? root_url : member_root_url)
  end

  def on_platform
    host! Rails.configuration.x.app_domain
  end

  def sign_in_as_platform_admin(platform_admin, password: "password")
    on_platform
    post platform_session_path, params: { email_address: platform_admin.email_address, password: }
  end
end

module SystemAuthenticationHelpers
  def visit_church(church)
    Capybara.app_host = "http://#{church.host}"
  end

  def sign_in_as(user, password: "password")
    visit_church(user.church)
    visit new_session_path
    fill_in "Email address", with: user.email_address
    fill_in "Password", with: password
    click_on "Sign in"
  end
end

RSpec.configure do |config|
  config.include RequestAuthenticationHelpers, type: :request
  config.include SystemAuthenticationHelpers, type: :system

  config.before(type: :system) { |example| driven_by :rack_test unless example.metadata[:js] }
  config.after(type: :system) { Capybara.app_host = nil }
end
