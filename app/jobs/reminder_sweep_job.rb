# Hourly (config/schedule.yml): at 8am in each church's own time zone, send that
# church's reminders. Scheduling::Reminders marks what it sends, so reruns are safe.
class ReminderSweepJob < ApplicationJob
  LOCAL_HOUR = 8

  queue_as :default

  def perform
    ActsAsTenant.without_tenant { Church.all.to_a }.each do |church|
      next unless church.now.hour == LOCAL_HOUR

      ActsAsTenant.with_tenant(church) { Scheduling::Reminders.new(church).send_due! }
    end
  end
end
