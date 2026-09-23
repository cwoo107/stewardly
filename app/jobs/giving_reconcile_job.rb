# Hourly (config/schedule.yml): at 2am in each church's zone, reconcile giving for
# churches with a connected giving provider. Also run on demand ("Sync now").
class GivingReconcileJob < ApplicationJob
  LOCAL_HOUR = 2

  queue_as :low

  def perform(integration = nil)
    return Giving::Reconciliation.new(integration).run!(kind: :manual) if integration

    ActsAsTenant.without_tenant { Integration.active.where(category: "giving").includes(:church).to_a }.each do |giving|
      next unless giving.church.now.hour == LOCAL_HOUR

      ActsAsTenant.with_tenant(giving.church) { Giving::Reconciliation.new(giving).run! }
    end
  end
end
