# Guards mounted engines (Sidekiq::Web) that sit outside our controllers.
module PlatformAdminSignedIn
  def self.matches?(request)
    session_id = request.cookie_jar.signed[:platform_session_id]
    session_id.present? && PlatformSession.exists?(session_id)
  end
end
