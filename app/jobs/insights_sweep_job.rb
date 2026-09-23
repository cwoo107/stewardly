# Hourly (config/schedule.yml): at 4am in each church's zone, run the insight checks.
class InsightsSweepJob < ApplicationJob
  LOCAL_HOUR = 4

  queue_as :low

  def perform
    ActsAsTenant.without_tenant { Church.all.to_a }.each do |church|
      next unless church.now.hour == LOCAL_HOUR

      ActsAsTenant.with_tenant(church) { Insights::Sweep.new(church).run! }
    end
  end
end
