# Nightly (config/schedule.yml): re-run pinned reports so dashboards open with fresh numbers.
class SavedReportRefreshJob < ApplicationJob
  queue_as :low

  def perform
    ActsAsTenant.without_tenant { Church.all.to_a }.each do |church|
      ActsAsTenant.with_tenant(church) { SavedReport.pinned.includes(:user).find_each(&:rerun!) }
    end
  end
end
