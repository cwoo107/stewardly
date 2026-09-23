# The bare app domain serves the platform console.
module PlatformHost
  def self.matches?(request)
    request.subdomain.blank?
  end
end
