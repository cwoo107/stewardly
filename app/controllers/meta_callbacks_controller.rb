# Meta's callbacks, on the platform domain (one registered address for every church).
#   oauth: the end of "Connect Facebook and Instagram". The signed state names the church
#     and user; the code is exchanged here, then the user goes back to their church.
#   deauthorize / data_deletion: required by Meta's app review. They arrive as a
#     signed_request (verified with the app secret) naming the Meta user.
class MetaCallbacksController < ActionController::Base
  skip_forgery_protection only: %i[ deauthorize data_deletion ]

  def oauth
    state = Social::Connection.read_state(params[:state])
    return render(plain: "This link has expired. Go back and choose Connect again.", status: :bad_request) unless state

    church = Church.find(state["church_id"])
    ActsAsTenant.with_tenant(church) do
      user = User.find(state["user_id"])
      return redirect_to(accounts_url(church, error: "Connecting was cancelled."), allow_other_host: true) if params[:code].blank?
      return head(:forbidden) unless user.can?(:manage_integrations)

      token, expires_at, meta_user_id, accounts = Social::Providers::Meta.connect(code: params[:code], redirect_uri: Social::Connection.redirect_uri)
      integration = Social::Connection.save!(user_token: token, expires_at:, meta_user_id:, accounts:)
      AuditEvent.create!(action: "social.connected", auditable: integration, actor: user, metadata: { "accounts" => accounts.size })
      redirect_to accounts_url(church, connected: accounts.size), allow_other_host: true
    rescue Social::Provider::Error => error
      redirect_to accounts_url(church, error: "Meta didn't connect: #{error.message}"), allow_other_host: true
    end
  end

  def deauthorize
    meta_user_id = signed_request_user_id or return head(:bad_request)
    disconnect(meta_user_id)
    head :ok
  end

  # Meta expects a status URL and a confirmation code back.
  # TODO(verify vendor docs): the { url, confirmation_code } response shape.
  def data_deletion
    meta_user_id = signed_request_user_id or return head(:bad_request)
    disconnect(meta_user_id, delete: true)
    code = Digest::SHA256.hexdigest("#{meta_user_id}-#{Rails.application.secret_key_base}").first(16)
    render json: { url: meta_deletion_status_url(code), confirmation_code: code }
  end

  def deletion_status
    render plain: "Stewardly deleted the Facebook and Instagram connection data for this request (#{params[:code]})."
  end

  private
    def accounts_url(church, **params)
      "#{Email::Tracking.base_url(church)}/social/accounts#{"?#{params.to_query}" if params.any?}"
    end

    # TODO(verify vendor docs): signed_request = base64url(HMAC-SHA256 signature) "." base64url(JSON payload with user_id).
    def signed_request_user_id
      signature, payload = params[:signed_request].to_s.split(".", 2)
      return if signature.blank? || payload.blank? || Social::Providers::Meta.app_secret.blank?

      expected = OpenSSL::HMAC.digest("SHA256", Social::Providers::Meta.app_secret, payload)
      return unless ActiveSupport::SecurityUtils.secure_compare(Base64.urlsafe_decode64(pad(signature)), expected)

      JSON.parse(Base64.urlsafe_decode64(pad(payload)))["user_id"].presence
    rescue ArgumentError, JSON::ParserError
      nil
    end

    def pad(value) = value + "=" * ((4 - value.length % 4) % 4)

    def disconnect(meta_user_id, delete: false)
      integrations = ActsAsTenant.without_tenant { Integration.where(category: "social", provider: "meta").where("settings->>'meta_user_id' = ?", meta_user_id.to_s).to_a }
      integrations.each do |integration|
        ActsAsTenant.with_tenant(integration.church) do
          integration.social_accounts.update_all(status: "disconnected", access_token: nil)
          delete ? integration.update!(status: :disabled, credentials: {}, settings: {}) : integration.update!(status: :disabled, credentials: {})
          AuditEvent.create!(action: delete ? "social.data_deleted" : "social.deauthorized", auditable: integration, metadata: {})
        end
      end
    end
end
