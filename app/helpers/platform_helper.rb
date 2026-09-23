module PlatformHelper
  # "yourchurch.localhost:3000" in development, "yourchurch.stewardly.app" in production.
  def church_sign_in_example
    port = request.port unless [ 80, 443 ].include?(request.port)
    "yourchurch.#{Rails.configuration.x.app_domain}#{":#{port}" if port}"
  end
end
