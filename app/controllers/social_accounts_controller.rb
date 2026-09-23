class SocialAccountsController < ApplicationController
  def index
    authorize SocialAccount
    @accounts = policy_scope(SocialAccount).alphabetical
    @configured = Social::Providers::Meta.configured?
    flash.now[:notice] = "Connected #{helpers.pluralize(params[:connected].to_i, "account")}." if params[:connected]
    flash.now[:alert] = params[:error] if params[:error].present?
  end

  # Off to Meta; the answer comes back to the platform's fixed callback (MetaCallbacksController).
  def connect
    authorize SocialAccount, :connect?
    return redirect_to(social_accounts_path, alert: "Facebook and Instagram aren't set up on this server yet (META_APP_ID and META_APP_SECRET).") unless Social::Providers::Meta.configured?

    state = Social::Connection.state_for(church: Current.church, user: Current.user)
    redirect_to Social::Providers::Meta.authorize_url(state:, redirect_uri: Social::Connection.redirect_uri), allow_other_host: true
  end

  def check
    account = authorize SocialAccount.find(params.expect(:id))
    account.provider.validate(account)
    account.update!(status: :connected, last_error: nil, checked_at: Time.current)
    redirect_to social_accounts_path, notice: "#{account.label} is working."
  rescue Social::Provider::Error => error
    account.update!(status: :needs_reconnect, last_error: error.message.first(255), checked_at: Time.current) if error.reconnect
    redirect_to social_accounts_path, alert: "#{account.label}: #{error.message}"
  end

  def destroy
    account = authorize SocialAccount.find(params.expect(:id))
    if account.targets.exists?
      account.update!(status: :disconnected, access_token: nil)
    else
      account.destroy!
    end
    redirect_to social_accounts_path, notice: "#{account.label} disconnected.", status: :see_other
  end
end
