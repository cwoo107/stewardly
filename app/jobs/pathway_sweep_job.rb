# Hourly (config/schedule.yml): at 3am in each church's zone, re-place everyone, so
# time-based rules ("served in the last 60 days") and stuck status stay current.
class PathwaySweepJob < ApplicationJob
  LOCAL_HOUR = 3

  queue_as :low

  def perform
    ActsAsTenant.without_tenant { Church.all.to_a }.each do |church|
      next unless church.now.hour == LOCAL_HOUR

      ActsAsTenant.with_tenant(church) { Pathway::Placement.new(Pathway.current).place_everyone! }
    end
  end
end
