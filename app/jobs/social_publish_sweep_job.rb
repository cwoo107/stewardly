# Every minute (config/schedule.yml): queue every due target, and mark any a crashed job
# left mid-publish as "unknown".
class SocialPublishSweepJob < ApplicationJob
  queue_as :default

  def perform
    ActsAsTenant.without_tenant { SocialPostTarget.due.pluck(:church_id, :id) }.each do |church_id, id|
      ActsAsTenant.with_tenant(Church.find(church_id)) { SocialPublishJob.perform_later(SocialPostTarget.find(id)) }
    end
    ActsAsTenant.without_tenant { Church.where(id: SocialPostTarget.publishing.select(:church_id)).to_a }.each do |church|
      ActsAsTenant.with_tenant(church) { Social::Publishing.mark_stuck! }
    end
  end
end
