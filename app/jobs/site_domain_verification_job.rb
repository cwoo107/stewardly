# Checks a new custom domain's DNS; hourly (config/schedule.yml) for every pending
# domain until it's verified or a week has passed.
class SiteDomainVerificationJob < ApplicationJob
  queue_as :low

  def perform(domain = nil)
    return domain.verify! if domain

    ActsAsTenant.without_tenant { SiteDomain.pending.where(created_at: 7.days.ago..).includes(:church).to_a }.each do |pending|
      ActsAsTenant.with_tenant(pending.church) { pending.verify! }
    end
  end
end
