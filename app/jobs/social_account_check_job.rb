# Daily (config/schedule.yml): check every connected account's token, so a broken
# connection shows up before a scheduled post fails.
class SocialAccountCheckJob < ApplicationJob
  queue_as :low

  def perform
    ActsAsTenant.without_tenant { SocialAccount.connected.includes(:church, :integration).to_a }.each do |account|
      ActsAsTenant.with_tenant(account.church) do
        account.provider.validate(account)
        account.update!(checked_at: Time.current)
      rescue Social::Provider::Error => error
        account.update!(status: :needs_reconnect, last_error: error.message.first(255), checked_at: Time.current) if error.reconnect
      end
    end
  end
end
