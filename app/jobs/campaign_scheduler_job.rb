# Every five minutes (config/schedule.yml): start campaigns whose send time has come.
class CampaignSchedulerJob < ApplicationJob
  queue_as :default

  def perform
    ActsAsTenant.without_tenant { Campaign.due.pluck(:church_id, :id) }.each do |church_id, id|
      ActsAsTenant.with_tenant(Church.find(church_id)) { CampaignDispatchJob.perform_later(Campaign.find(id)) }
    end
  end
end
