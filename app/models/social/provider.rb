# The interface every social network adapter implements. The rest of the app only
# talks to this.
class Social::Provider
  class Error < StandardError
    # transient: worth retrying. reconnect: the account's token no longer works.
    attr_reader :transient, :reconnect

    def initialize(message, transient: false, reconnect: false)
      super(message)
      @transient = transient
      @reconnect = reconnect
    end
  end

  AccountRecord = Data.define(:network, :external_id, :name, :handle, :avatar_url, :access_token, :token_expires_at)
  PublishResult = Data.define(:external_post_id, :permalink)
  Limits = Data.define(:caption_length, :max_photos, :photo_required, :links_clickable)

  def self.authorize_url(state:, redirect_uri:) = raise(NotImplementedError)

  # Exchanges an OAuth code for the user's token and the accounts they manage:
  # [user_token, token_expires_at, provider_user_id, [AccountRecord]].
  def self.connect(code:, redirect_uri:) = raise(NotImplementedError)

  def self.limits(network) = raise(NotImplementedError)

  # Publishes a target (post text, link, photos) and returns a PublishResult.
  def publish(target, photo_urls:) = raise(NotImplementedError)

  # Raises Error (reconnect: true) when the account can't be posted to any more.
  def validate(account) = raise(NotImplementedError)
end
