# Connecting a church's Meta login: saves the integration (with the long-lived user
# token) and every Page and Instagram account it manages. Reconnecting refreshes tokens
# and brings accounts that needed it back to "connected".
module Social::Connection
  # The OAuth round trip leaves from the church's subdomain and returns to one fixed
  # callback on the platform domain (Meta needs redirect URIs registered in advance), so
  # the church and user travel in a signed, expiring state.
  def self.state_for(church:, user:)
    verifier.generate({ "church_id" => church.id, "user_id" => user.id, "nonce" => SecureRandom.hex(8) }, expires_in: 15.minutes, purpose: :meta_oauth)
  end

  def self.read_state(state) = verifier.verified(state.to_s, purpose: :meta_oauth)

  def self.redirect_uri
    host = Rails.configuration.x.app_domain
    Rails.env.production? ? "https://#{host}/oauth/meta/callback" : "http://#{host}:#{Rails.configuration.x.dev_port.presence || 3000}/oauth/meta/callback"
  end

  def self.save!(user_token:, expires_at:, meta_user_id:, accounts:)
    Integration.transaction do
      integration = Integration.find_or_initialize_by(category: "social", provider: "meta")
      integration.update!(status: :active, credentials: { "user_access_token" => user_token },
        settings: integration.settings.to_h.merge("meta_user_id" => meta_user_id, "token_expires_at" => expires_at&.iso8601).compact)
      accounts.each do |record|
        account = SocialAccount.find_or_initialize_by(network: record.network, external_id: record.external_id)
        account.update!(integration:, name: record.name, handle: record.handle, avatar_url: record.avatar_url, access_token: record.access_token,
          token_expires_at: record.token_expires_at, status: :connected, last_error: nil, checked_at: Time.current)
      end
      integration
    end
  end

  def self.verifier = Rails.application.message_verifier(:social_oauth)
end
