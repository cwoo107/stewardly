# Hourly (config/schedule.yml): at 6am in each church's zone, start runs for "missed N
# weeks" and "N days before/after a date" workflows.
class WorkflowSweepJob < ApplicationJob
  LOCAL_HOUR = 6

  queue_as :low

  def perform
    ActsAsTenant.without_tenant { Church.all.to_a }.each do |church|
      next unless church.now.hour == LOCAL_HOUR

      ActsAsTenant.with_tenant(church) { Workflow::Sweep.new(church).run! }
    end
  end
end
